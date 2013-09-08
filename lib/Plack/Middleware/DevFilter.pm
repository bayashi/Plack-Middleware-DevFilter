package Plack::Middleware::DevFilter;
use strict;
use warnings;
use Carp qw/croak/;
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw/force_enable filters image_type/;
use Plack::Util;

our $VERSION = '0.01';

sub prepare_app {
    my $self = shift;

    croak "'filters' option must be ARRAY." unless ref $self->filters eq 'ARRAY';

    unless ($self->image_type) {
        $self->image_type(
            sub {
                my ($env, $res) = @_;

                my $ct = Plack::Util::header_get($res->[1], 'content-type');
                my $image_type = ($ct =~ m!(png|gif|jpeg|ico)!) ? $1 : undef;
                return $image_type;
            },
        );
    }
}

sub call {
    my($self, $env) = @_;

    my $res = $self->app->($env);

    if ( !$self->force_enable
            && (!$ENV{PLACK_ENV} || $ENV{PLACK_ENV} !~ m!^(?:development|test)$!) ) {
        return $res;
    }

    my $body = '';
    Plack::Util::foreach($res->[2], sub {
        my($buf) = @_;
        $body .= $buf;
    });

    my ($imager, $image_type);
    if ( $image_type = $self->image_type->($env, $res) ) {
        require Imager;
        $imager = Imager->new(
            data => $body,
            type => $image_type,
        ) or croak Imager->errstr;
    }

    my $filtered = 0;
    for my $filter (@{$self->filters}) {
        if ( $filter->{match}->($self, $env) ) {
            $filter->{proc}->($self, $env, $res,
                                    \$body, $imager, $image_type);
            $filtered = 1;
        }
    }

    return $filtered ? $res : [ $res->[0], $res->[1], [$body] ];
}

1;

__END__

=head1 NAME

Plack::Middleware::DevFilter - one line description


=head1 SYNOPSIS

    use Plack::Builder;

    builder {
        enable 'DevFilter',
            filters => [
                { # favicon.ico
                    match => sub {
                        my ($self, $env, $res) = @_;
                        return 1 if $env->{PATH_INFO} eq '/favicon.ico';
                    },
                    proc  => sub {
                        my ($self, $env, $res,
                                $body_ref, $imager, $image_type) = @_;
                        if ($imager) {
                            $imager = $imager->convert(preset => 'gray')
                                            or die Imager->errstr;
                            my $out;
                            $imager->write(data => \$out, type => $image_type);
                            $res->[2] = [$out];
                        }
                    },
                },
            ],
        ;
    };

=head1 DESCRIPTION

Plack::Middleware::DevFilter is


=head1 REPOSITORY

Plack::Middleware::DevFilter is hosted on github
<http://github.com/bayashi/Plack-Middleware-DevFilter>

Welcome your patches and issues :D


=head1 AUTHOR

Dai Okabayashi E<lt>bayashi@cpan.orgE<gt>


=head1 SEE ALSO

L<Plack::Middleware>

L<Imager>

This module was inspired by L<Plack::Middleware::DevFavicon>.


=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
