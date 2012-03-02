
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "AnyEvent::Multi::Curl (libcurl) backend for ElasticSearch",
  "AUTHOR" => "Clinton Gormley <drtech\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Test::More" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "ElasticSearch-Transport-AECurl",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "ElasticSearch::Transport::AECurl",
  "PREREQ_PM" => {
    "AnyEvent::Curl::Multi" => 0,
    "ElasticSearch" => "0.50",
    "ElasticSearch::Transport::AEHTTP" => "0.04",
    "ElasticSearch::Util" => 0,
    "Encode" => 0,
    "Guard" => 0,
    "HTTP::Request" => 0,
    "Scalar::Util" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



