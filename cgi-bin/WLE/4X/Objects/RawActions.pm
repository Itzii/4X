package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Methods::Simple;



#############################################################################

sub _raw_add_source {
    my $self        = shift;
    my $tag         = shift;

    push( @{ $self->{'DATA'}->{'SOURCE_TAGS' } } );

    return;
}

#############################################################################

sub _raw_remove_source {
    my $self        = shift;
    my $tag         = shift;

    my @current_tags = $self->source_tags();
    $self->{'DATA'}->{'SOURCE_TAGS'} = [];

    foreach my $t ( @current_tags ) {
        unless ( $t eq $tag ) {
            push( @{ $self->{'DATA'}->{'SOURCE_TAGS'} }, $t );
        }
    }

    return;
}

#############################################################################

sub _raw_add_player {
    my $self        = shift;
    my $player_id   = shift;

    push( @{ $self->{'DATA'}->{'PLAYER_IDS'} }, $player_id );

    return;
}


#############################################################################

sub _raw_remove_player {
    my $self        = shift;
    my $player_id   = shift;

    my @current_ids = $self->player_ids();
    $self->{'DATA'}->{'PLAYER_IDS'} = [];

    foreach my $id ( @current_ids ) {
        unless ( $id == $player_id ) {
            push( @{ $self->{'DATA'}->{'PLAYER_IDS'} }, $id );
        }
    }

    return;
}


#############################################################################
#############################################################################
1
