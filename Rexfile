
=head1 NAME

Rexfile - Rex task configuration for CPAN Testers web application

=head1 SYNOPSIS

    # Deploy the latest web app from CPAN
    rex deploy

    # Deploy the latest tarball to our VM from the local directory
    rex -E vm deploy_dev

=head1 DESCRIPTION

This file defines all the L<Rex|http://rexify.org> tasks used to deploy
this application.

You must have already configured a user using the
L<cpantesters-deploy|http://github.com/cpan-testers/cpantesters-deploy>
repository, or been given an SSH key to use this Rexfile.

=head1 SEE ALSO

L<Rex|http://rexify.org>

=cut

use Rex -feature => [ 1.4 ];
use Rex::Commands::Sync;

#######################################################################
# Groups
group web => 'cpantesters4.dh.bytemark.co.uk';

#######################################################################
# Settings

user 'cpantesters';
private_key '~/.ssh/cpantesters-rex';

# Used to find local, dev copies of the dist
set 'dist_name' => 'CPAN-Testers-Web';

#######################################################################
# Environments
# The Vagrant VM for development purposes
environment vm => sub {
    group api => '192.168.127.127'; # the Vagrant VM IP
    set 'no_sudo_password' => 1;
};

#######################################################################

=head1 TASKS

=head2 deploy

    rex deploy
    rex -E vm deploy

Deploy the CPAN Testers web app from CPAN. Do this task after releasing
a version of CPAN::Testers::Web to CPAN.

=cut

desc "Deploy the CPAN Testers Web app from CPAN";
task deploy =>
    group => 'web',
    sub {
        run 'source ~/.profile; cpanm CPAN::Testers::Web DBD::mysql';
        run_task 'deploy_config', on => connection->server;
    };

=head2 deploy_dev

    rex -E vm deploy_dev

Deploy a pre-release, development version of the web app. Use this to
install to your dev VM to test things. Will run `dzil build` locally
to build the tarball, then sync that tarball to the remote and install
using `cpanm`.

=cut

task deploy_dev =>
    group => 'web',
    sub {
        my $dist_name = get 'dist_name';
        my $dist;
        LOCAL {
            Rex::Logger::info( 'Building dist' );
            run 'dzil build';
            my @dists = sort glob "${dist_name}-*.tar.gz";
            $dist = $dists[-1];
        };

        Rex::Logger::info( 'Syncing ' . $dist );
        file '~/dist/' . $dist,
            source => $dist;

        Rex::Logger::info( 'Installing ' . $dist );
        run 'source ~/.profile; cpanm -v --notest ~/dist/' . $dist . ' 2>&1';
        if ( $? ) {
            say last_command_output;
        }
        run_task 'deploy_config', on => connection->server;
    };

=head2 deploy_config

    rex deploy_config

Deploy the service scripts and configuration files, and then restart
the services.

=cut

task deploy_config =>
    group => 'web',
    sub {
        Rex::Logger::info( 'Deploying service config' );
        file '~/service/web/log',
            ensure => 'directory';
        file '~/service/web/run',
            source => 'etc/runit/web/run';
        file '~/service/web/web.conf',
            source => 'etc/runit/web/web.conf';
        file '~/service/web/log/run',
            source => 'etc/runit/web/log/run';
        file '~/service/web-beta/log',
            ensure => 'directory';
        file '~/service/web-beta/run',
            source => 'etc/runit/web-beta/run';
        file '~/service/web-beta/web.conf',
            source => 'etc/runit/web-beta/web.conf';
        file '~/service/web-beta/log/run',
            source => 'etc/runit/web-beta/log/run';

        Rex::Logger::info( 'Restarting' );
        run 'sv restart ~/service/web';
        run 'sv restart ~/service/web-beta';
    };

#######################################################################

=head1 SUBROUTINES

=head2 ensure_sudo_password

Ensure a C<sudo> password is set. Use this at the start of any task
that requires C<sudo>.

=cut

sub ensure_sudo_password {
    return if sudo_password();
    return if get 'no_sudo_password';
    print 'Password to use for sudo: ';
    ReadMode('noecho');
    sudo_password ReadLine(0);
    ReadMode('restore');
    print "\n";
}

