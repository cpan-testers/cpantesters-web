requires "CPAN::Testers::Report" => "1.999003";
requires "CPAN::Testers::Schema" => "0.004";
requires "Carp" => "0";
requires "DBIx::Connector" => "0.56";
requires "Data::FlexSerializer" => "1.10";
requires "File::Share" => "0.25";
requires "File::Spec::Functions" => "0";
requires "Import::Base" => "0.012";
requires "JSON" => "2.90";
requires "Log::Any" => "1.045";
requires "Log::Any::Adapter" => "0";
requires "Log::Any::Adapter::MojoLog" => "0.02";
requires "Metabase::Resource" => "0.025";
requires "Metabase::Resource::cpan::distfile" => "0.025";
requires "Metabase::Resource::metabase::user" => "0.025";
requires "Mojo::Base" => "0";
requires "Mojolicious" => "6";
requires "Mojolicious::Commands" => "0";
requires "Mojolicious::Lite" => "0";
requires "Mojolicious::Plugin::AssetPack" => "0";
requires "Mojolicious::Plugin::Config" => "0";
requires "Mojolicious::Validator" => "0";
requires "Set::Tiny" => "0.04";
requires "Try::Tiny" => "0.27";
requires "perl" => "5.024";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Test::Lib" => "0";
  requires "Test::Mojo" => "0";
  requires "Test::More" => "1.001005";
  requires "blib" => "1.01";
  requires "perl" => "5.024";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::ShareDir::Install" => "0.06";
};
