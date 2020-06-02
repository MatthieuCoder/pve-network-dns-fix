package PVE::Network::SDN::VnetPlugin;

use strict;
use warnings;

use PVE::Cluster qw(cfs_read_file cfs_write_file cfs_lock_file);
use base qw(PVE::SectionConfig);
use PVE::JSONSchema qw(get_standard_option);

PVE::Cluster::cfs_register_file('sdn/vnets.cfg',
                                 sub { __PACKAGE__->parse_config(@_); },
                                 sub { __PACKAGE__->write_config(@_); });

PVE::JSONSchema::register_standard_option('pve-sdn-vnet-id', {
    description => "The SDN vnet object identifier.",
    type => 'string', format => 'pve-sdn-vnet-id',
});

PVE::JSONSchema::register_format('pve-sdn-vnet-id', \&parse_sdn_vnet_id);
sub parse_sdn_vnet_id {
    my ($id, $noerr) = @_;

    if ($id !~ m/^[a-z][a-z0-9]*[a-z0-9]$/i) {
        return undef if $noerr;
        die "vnet ID '$id' contains illegal characters\n";
    }
    die "vnet ID '$id' can't be more length than 8 characters\n" if length($id) > 8;
    return $id;
}

my $defaultData = {

    propertyList => {
        vnet => get_standard_option('pve-sdn-vnet-id',
            { completion => \&PVE::Network::SDN::Vnets::complete_sdn_vnet }),
    },
};

sub type {
    return 'vnet';
}

sub private {
    return $defaultData;
}

sub properties {
    return {
	zone => {
            type => 'string',
            description => "zone id",
	},
        type => {
            description => "Type",
            optional => 1,
        },
	tag => {
            type => 'integer',
            description => "vlan or vxlan id",
	},
	vlanaware => {
	    type => 'boolean',
	    description => 'Allow vm VLANs to pass through this vnet.',
	},
        alias => {
            type => 'string',
            description => "alias name of the vnet",
	    optional => 1,
        },
        ipv4 => {
            description => "Anycast router ipv4 address.",
            type => 'string', format => 'CIDRv4',
            optional => 1,
        },
	ipv6 => {
	    description => "Anycast router ipv6 address.",
	    type => 'string', format => 'CIDRv6',
	    optional => 1,
	},
        mac => {
            type => 'string',
            description => "Anycast router mac address",
	    optional => 1, format => 'mac-addr'
        }
    };
}

sub options {
    return {
        zone => { optional => 0},
        tag => { optional => 0},
        alias => { optional => 1 },
        ipv4 => { optional => 1 },
        ipv6 => { optional => 1 },
        mac => { optional => 1 },
        vlanaware => { optional => 1 },
    };
}

sub on_delete_hook {
    my ($class, $sdnid, $vnet_cfg) = @_;

    return;
}

sub on_update_hook {
    my ($class, $vnetid, $vnet_cfg) = @_;
    # verify that tag is not already defined in another vnet
    if (defined($vnet_cfg->{ids}->{$vnetid}->{tag})) {
	my $tag = $vnet_cfg->{ids}->{$vnetid}->{tag};
	foreach my $id (keys %{$vnet_cfg->{ids}}) {
	    next if $id eq $vnetid;
	    my $vnet = $vnet_cfg->{ids}->{$id};
	    if ($vnet->{type} eq 'vnet' && defined($vnet->{tag})) {
		die "tag $tag already exist in vnet $id" if $tag eq $vnet->{tag};
	    }
	}
    }
}

1;
