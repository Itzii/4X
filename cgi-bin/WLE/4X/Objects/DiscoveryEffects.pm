package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Objects::Element;
use WLE::4X::Objects::ShipComponent;

#############################################################################

sub use_discovery {
    my $self            = shift;
    my $tile_tag        = shift;
    my $discovery_tag   = shift;

    my $discovery = $self->discoveries()->{ $discovery_tag };
    my $race = $self->race_of_acting_player();

    if ( $discovery->adds_component() ) {
        $race->add_hand_item( $discovery->component() );
        return 1;
    }
    elsif ( $discovery->adds_resource() ) {
        foreach my $resource ( keys( %{ $discovery->resources() } ) ) {
            $race->add_resource( $resource, $discovery->resources()->{ $resource } );
        }

        return 1;
    }
    elsif ( $discovery->tag() eq 'disc_cruiser' ) {
        my $template = $race->template_of_class( 'class_cruiser' );

        unless ( defined( $template ) ) {
            return 0;
        }

        unless ( $template->count() > 0 || $self->has_option( 'option_unlimited_ships' ) ) {
            return 0;
        }

        $self->_raw_create_ship_on_tile( $EV_SUB_ACTION, $tile_tag, $template->tag(), $race->owner_id() );

        return 1;
    }
    elsif ( $discovery->tag() eq 'disc_interceptors' ) {
        my $template = $race->template_of_class( 'class_interceptor' );

        unless ( defined( $template ) ) {
            return 0;
        }

        unless ( $template->count() > 0 || $self->has_option( 'option_unlimited_ships' ) ) {
            return 0;
        }

        my $resource = 6;

        while ( $resource >= $template->cost() ) {
            $resource -= $template_cost();
            $self->_raw_create_ship_on_tile( $EV_SUB_ACTION, $tile_tag, $template->tag(), $race->owner_id() );
        }

        return 1;
    }
    elsif ( $discovery->tag() eq 'disc_ring' ) {
        $self->_raw_add_slot_to_tile( $EV_SUB_ACTION, $tile_tag, $RES_SCIENCE_MONEY, 0 );
        $self->_raw_add_ancient_link_to_tile( $EV_SUB_ACTION, $tile_tag );

        return 1;
    }
    elsif ( $discovery->tag() eq 'disc_wormhole' ) {
        my $tile = $self->tiles()->{ $tile_tag };

        unless ( defined( $tile ) ) {
            return 0;
        }

        $tile->_raw_add_wormhole_to_tile( $EV_SUB_ACTION, $tile_tag );
        $tile->_raw_add_vp_to_tile( $EV_SUB_ACTION, $tile_tag );

        return 1;
    }
    elsif ( $discovery()->tag() eq 'disc_technology' ) {

        my $tech_list = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );

        my $lowest = 999;

        foreach my $tech_tag ( $self->available_tech()->items() ) {
            my $tech = $self->tech()->{ $tech_tag };

            if ( $race->has_technology( $tech->provides() ) ) {
                next;
            }

            if ( $tech->type() == $TECH_WILD ) {
                next;
            }

            if ( $tech->base_cost() == $lowest ) {
                $tech_list->add_items( $tech_tag );
            }
            elsif ( $tech->base_cost() < $lowest ) {
                $lowest = $tech->base_cost();
                $tech_list->clear();
                $tech_list->add_items( $tech_tag );
            }
        }

        $race->in_hand()->add_items( $tech_list->items() );
    }

    return 0;
}

#############################################################################
#############################################################################
1
