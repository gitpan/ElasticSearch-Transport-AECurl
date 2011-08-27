
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601",
    "Test::More" => 0
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "AnyEvent::Multi::Curl (libcurl) backend for ElasticSearch",
  "dist_author" => [
    "Clinton Gormley <drtech\@cpan.org>"
  ],
  "dist_name" => "ElasticSearch-Transport-AECurl",
  "dist_version" => "0.02",
  "license" => "perl",
  "module_name" => "ElasticSearch::Transport::AECurl",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "AnyEvent::Curl::Multi" => 0,
    "ElasticSearch" => "0.44",
    "ElasticSearch::Transport::AEHTTP" => "0.02",
    "ElasticSearch::Util" => 0,
    "Encode" => 0,
    "Guard" => 0,
    "HTTP::Request" => 0,
    "Scalar::Util" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
