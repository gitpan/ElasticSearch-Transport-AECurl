package ElasticSearch::Transport::AECurl;

use strict;
use warnings;

use ElasticSearch 0.60                    ();
use ElasticSearch::Transport::AEHTTP 0.05 ();
use parent 'ElasticSearch::Transport::AEHTTP';
use AnyEvent::Curl::Multi();
use HTTP::Request();
use Encode qw(decode_utf8 encode_utf8);
use ElasticSearch::Util qw(build_error);
use Scalar::Util qw(weaken);
use Guard qw(guard);

our $VERSION = '0.05';

#===================================
sub init {
#===================================
    my $self   = shift;
    my $params = shift;
    for (qw(proxy max_concurrency max_redirects ipresolve)) {
        next unless exists $params->{$_};
        $self->$_( delete $params->{$_} );
    }
}

#===================================
sub _send_request {
#===================================
    my $self   = shift;
    my $server = shift;
    my $params = shift;
    my $cb     = shift;

    my $method  = $params->{method};
    my $uri     = $self->http_uri( $server, $params->{cmd}, $params->{qs} );
    my $request = HTTP::Request->new( $method, $uri );

    if ( defined $params->{data} ) {
        $request->add_content_utf8( $params->{data} );
        eval { $self->check_content_length( $request->content_ref ); 1 }
            or $cb->( undef, $@ );
        $request->header( 'Expect' => '' );
    }

    my $request_cb = sub {
        my ( $code, $msg, $content ) = ( 0, $@ );
        if ( my $response = shift ) {
            $content = $response->content;
            $content = decode_utf8($content) if defined $content;
            return $cb->($content) if $response->is_success;

            $msg  = $response->message;
            $code = $response->code;
        }

        my $type = $self->code_to_error($code)
            || (
            $msg =~ /Operation timed out/
            ? 'Timeout'
            : $msg =~ /  couldn't.connect
                       | connect.*time
                       | send.failure
                       | Could.only.read
                       | transfer.closed
                       | Upload.failed
                      /xi
            ? 'Connection'
            : 'Request'
            );

        my $error_params = {
            server      => $server,
            status_code => $code,
            status_msg  => $msg,
        };

        $error_params->{content} = $content
            unless $type eq 'Timeout';

        my $error = build_error( $self, $type, $msg, $error_params );
        $cb->( undef, $error );
    };

    my $client = $self->client;
    my $handle = $client->request($request);
    $handle->{easy_h}->setopt(
        WWW::Curl::Easy::CURLOPT_ENCODING,
        $self->deflate ? 'deflate' : undef
    );
    my $cv = bless $handle->cv, 'ElasticSearch::Transport::AnyEvent::CondVar';
    $cv->cb($request_cb);

    return guard { $client->cancel($handle) } if defined wantarray;
}

#===================================
sub proxy {
#===================================
    my $self = shift;
    if (@_) {
        $self->{_proxy} = shift();
        $self->clear_clients;
    }
    return $self->{_proxy};
}

#===================================
sub max_concurrency {
#===================================
    my $self = shift;
    if (@_) {
        $self->{_max_concurrency} = shift();
        $self->clear_clients;
    }
    return $self->{_max_concurrency};
}

#===================================
sub max_redirects {
#===================================
    my $self = shift;
    if (@_) {
        $self->{_max_redirects} = shift();
        $self->clear_clients;
    }
    return $self->{_max_redirects};
}

#===================================
sub ip_resolve {
#===================================
    my $self = shift;
    if (@_) {
        $self->{_ip_resolve} = shift();
        $self->clear_clients;
    }
    return $self->{_ip_resolve};
}

#===================================
sub client {
#===================================
    my $self = shift;
    unless ( $self->{_client}{$$} ) {
        $self->{_client} = {
            $$ => AnyEvent::Curl::Multi->new(
                map { $_ => $self->$_ }
                    qw( timeout max_concurrency
                    max_redirects proxy ip_resolve)
            )
        };

    }
    return $self->{_client}{$$};
}

1;

# ABSTRACT: AnyEvent::Multi::Curl (libcurl) backend for ElasticSearch


__END__
=pod

=head1 NAME

ElasticSearch::Transport::AECurl - AnyEvent::Multi::Curl (libcurl) backend for ElasticSearch

=head1 VERSION

version 0.05

=head1 SYNOPSIS

    use ElasticSearch;
    my $e = ElasticSearch->new(
        servers         => 'search.foo.com:9200',
        transport       => 'aecurl',

        timeout         => 30,
        max_concurrency => 0,
        proxy           => 'foo.bar.com',
        ip_resolve      => 4|6|undef,
    );

    # blocking request
    $e->cluster_health->recv;

    # non-blocking request
    $e->cluster_health->cb( sub {
        if ($@) {
            log "An error occurred: $@";
        } else {
            my $response = shift;
            log $response;
        }
    });
    AE::cv->recv();

    # fire-and-forget vs scoped
    {
        $e->delete_index(index => 'foo');
        $e->delete_index(index => 'bar')->cb( sub { print "Done"});
        my $cv = $e->delete_index(index=>'baz');
    }
    AE::cv->recv;
    #   - foo and bar will be deleted
    #   - baz will not be deleted

=head1 DESCRIPTION

ElasticSearch::Transport::AECurl uses L<AnyEvent::Multi::Curl> (and thus
C<libcurl>) to talk to L<ElasticSearch> asynchronously over HTTP.

=head1 USING AECurl

Any request to ElasticSearch returns an L<AnyEvent::CondVar>. You have
three options for how you use them:

=head2 Blocking

    $cv = $e->cluster_health;
    $result = $cv->recv;

When you call C<recv()> on a CondVar, your program will block until
that CondVar is ready to return a value.

If an error was thrown, then C<recv()> will C<die>.  You will need to wrap
C<recv()> in C<eval> if you don't want to die.

If your C<$cv> goes out of scope, then the request will be aborted.

=head2 Callback

    $e->cluster_health->cb( sub {
        if ($@) {
            log "Error $@";
        }
        else {
            my $result = shift;
            log "$result"
        }
    })
    AE::cv->recv()

If you set a callback on a CondVar, then the callback will be called once
the CondVar is ready (which will only happen after you start the event loop).

In the callback, C<$@> will contain any error, otherwise the result (if any)
will be the first value in C<@_>.

Once you set a callback on a CondVar, it will not be aborted when it goes
out of scope.

=head2 Fire-and-Forget

    $e->delete_index(index=>'foo');

If a request is called in C<void> context, then it will be executed once
the event loop is started. No errors will be thrown, even if the request
does not complete succesfully.

It will not be aborted with a change in scope, because there is no scope. If
you exit the application without running an event loop, then any pending
requests will not be run.

=head1 BLOCKING METHODS

L<ElasticSearch/"scrolled_search()"> and L<ElasticSearch/"reindex()"> will
be executed synchronously.

=head1 SETTINGS

See L<AnyEvent::Curl::Multi> for an explanation of the C<max_concurrency()>,
C<max_redirects()>, C<proxy()> and C<ip_resolve()>

=head1 SEE ALSO

=over

=item * L<ElasticSearch>

=item * L<ElasticSearch::Transport>

=item * L<ElasticSearch::Transport::HTTPLite>

=item * L<ElasticSearch::Transport::HTTPTiny>

=item * L<ElasticSearch::Transport::Curl>

=item * L<ElasticSearch::Transport::AEHTTP>

=item * L<ElasticSearch::Transport::Thrift>

=back

1;

=head1 AUTHOR

Clinton Gormley <drtech@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Clinton Gormley.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

