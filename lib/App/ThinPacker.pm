package App::ThinPacker;

=pod

=head1 NAME

App::ThinPacker - enable your scripts to autoinstall their dependencies

=head1 DESCRIPTION

Enables your scripts to autoinstall their dependencies by injecting a small piece of code which downloads L<cpanminus> and uses it to install all the depenencies.

=head1 SYNOPSIS

    thinpack your-script.pl > your-script-dist.pl

    thinpack your-script.pl --sudo > your-script.pl

=head2 NOTE ABOUT CPANM

You can specify custom arguments after your script filename. Those arguments will be passed to all C<cpanm> calls.

This way you can enable interactive installation (C<--interactive>), disable testing (C<--no-test>), require root privelegies (C<--sudo>), and do other useful things. For more options see L<App::cpanminus>.

=head1 SEE ALSO

L<App::FatPacker>

L<App::cpanminus>

=head1 BUGS AND TODO

=over 4

=item No Windows support

=item Rudimentary parsing

=item Downloading cpanm from third-party source

=back

=head1 AUTHOR

Alex Kapranoff E<lt>kappa@cpan.orgE<gt>

=head1 CONTRIBUTORS

Alexey Surikov E<lt>ksuri@cpan.orgE<gt>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.

=cut

use 5.008;
use strict;
use warnings;

use PPI;
use Pod::Find;
use Pod::Usage;

our $VERSION = '0.2';

sub run {
    my $arg = shift or usage();
    usage(2) if $arg eq '-h' or $arg eq '--help';

    my $cpanm_args = join ' ', @_;

    my $ppi      = PPI::Document->new($arg) or usage();
    my $includes = $ppi->find('Statement::Include');

    my $deps = join ' ',
               grep { $_ }
               map  { $_->module }
               @$includes;

    my $inject = join '', map { s/%%DEPS%%/$deps/; s/%%CPANMARGS%%/$cpanm_args/g; $_ } <DATA>;

    open my $script, '<', $arg or exit print "Cannot open $arg: $!\n";
    my $not_injected = 1;
    while (my $line = <$script>) {
        if ($line =~ /^use / && $not_injected) {
            print "BEGIN {\n$inject\n}\n";
            $not_injected = 0;
        }

        print $line;
    }
}

sub usage {
    pod2usage(
        -verbose => $_[0] || 0,
        -output  => \*STDERR,
        -input   => Pod::Find::pod_where(
            { -inc => 1 },
            __PACKAGE__,
        ),
    );
}

__DATA__
    package main;
    use IO::Socket::INET;
    my @deps = qw(%%DEPS%%);
    my @missing;
    for my $dep (@deps) {
        local $@;
        eval "require $dep";
        push @missing, $dep if $@ and $@ =~ /^Can't locate/;
    }
    if (@missing) {
        local $@;
        eval "require App::cpanminus";
        if ($@) {
            my $sock = IO::Socket::INET->new('kapranoff.ru:80');
            print $sock join "\r\n", "GET /cpanm HTTP/1.0",
                                     "Connection: close",
                                     "\r\n";
            my $cpanm = do { local $/; <$sock> };
            close $sock;
            open my $perl, '|perl - --self-upgrade %%CPANMARGS%%';
            print $perl $cpanm;
            close $perl;
        }
        system(qw/cpanm %%CPANMARGS%%/, @missing);
    }
