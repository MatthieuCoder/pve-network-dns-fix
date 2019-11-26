package PVE::Network::SDN::Zones::QinQPlugin;

use strict;
use warnings;
use PVE::Network::SDN::Zones::VlanPlugin;

use base('PVE::Network::SDN::Zones::VlanPlugin');

sub type {
    return 'qinq';
}

sub properties {
    return {
        tag => {
            type => 'integer',
            description => "vlan tag",
        },
	'vlan-protocol' => {
	    type => 'string',
            enum => ['802.1q', '802.1ad'],
	    default => '802.1q',
	    optional => 1,
	    description => "vlan protocol",
	}
    };
}

sub options {

    return {
	'uplink-id' => { optional => 0 },
	'tag' => { optional => 0 },
	'vlan-protocol' => { optional => 1 },
    };
}

# Plugin implementation
sub generate_sdn_config {
    my ($class, $plugin_config, $zoneid, $vnetid, $vnet, $uplinks, $config) = @_;

    my $tag = $vnet->{tag};
    my $transport_tag = $plugin_config->{tag};
    my $mtu = $vnet->{mtu};
    my $alias = $vnet->{alias};
    my $vlanprotocol = $plugin_config->{'vlan-protocol'};
    my $uplink = $plugin_config->{'uplink-id'};

    die "missing vlan tag" if !$tag;
    die "missing transport vlan tag" if !$transport_tag;

    my $iface = $uplinks->{$uplink}->{name};
    $iface = "uplink${uplink}" if !$iface;
    $iface .= ".$transport_tag";

    #tagged interface
    my @iface_config = ();
    push @iface_config, "vlan-protocol $vlanprotocol" if $vlanprotocol;
    push @iface_config, "mtu $mtu" if $mtu;
    push(@{$config->{$iface}}, @iface_config) if !$config->{$iface};

    $iface .= ".$tag";
    #vnet bridge
    @iface_config = ();
    push @iface_config, "bridge_ports $iface";
    push @iface_config, "bridge_stp off";
    push @iface_config, "bridge_fd 0";
    push @iface_config, "mtu $mtu" if $mtu;
    push @iface_config, "alias $alias" if $alias;
    push(@{$config->{$vnetid}}, @iface_config) if !$config->{$vnetid};

    return $config;
}

1;


