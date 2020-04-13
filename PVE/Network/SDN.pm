package PVE::Network::SDN;

use strict;
use warnings;

use Data::Dumper;
use JSON;

use PVE::Network::SDN::Vnets;
use PVE::Network::SDN::Zones;

use PVE::Tools qw(extract_param dir_glob_regex run_command);
use PVE::Cluster qw(cfs_read_file cfs_write_file cfs_lock_file);


my $version_cfg = "sdn/.version";

my $parse_version_cfg = sub {
    my ($filename, $raw) = @_;

    warn "invalid sdn version" if $raw !~ m/\d+$/;

    return $raw,
};

my $write_version_cfg = sub {
    my ($filename, $version) = @_;

    warn "invalid sdn version" if $version !~ m/\d+$/;

    return $version;
};

PVE::Cluster::cfs_register_file($version_cfg, $parse_version_cfg, $write_version_cfg);


# improve me : move status code inside plugins ?

sub ifquery_check {

    my $cmd = ['ifquery', '-a', '-c', '-o','json'];

    my $result = '';
    my $reader = sub { $result .= shift };

    eval {
	run_command($cmd, outfunc => $reader);
    };

    my $resultjson = decode_json($result);
    my $interfaces = {};

    foreach my $interface (@$resultjson) {
	my $name = $interface->{name};
	$interfaces->{$name} = {
	    status => $interface->{status},
	    config => $interface->{config},
	    config_status => $interface->{config_status},
	};
    }

    return $interfaces;
}

sub status {

    my ($zone_status, $vnet_status) = PVE::Network::SDN::Zones::status();
    return($zone_status, $vnet_status);
}


sub increase_version {

    my $version = cfs_read_file($version_cfg);

    if($version) {
	$version++;
    } else {
	$version = 1;
    }

    cfs_write_file($version_cfg, $version);
}

sub lock_sdn_config {
    my ($code, $errmsg) = @_;

    cfs_lock_file($version_cfg, undef, $code);

    if (my $err = $@) {
        $errmsg ? die "$errmsg: $err" : die $err;
    }
}

sub get_local_vnets {

    my $rpcenv = PVE::RPCEnvironment::get();

    my $authuser = $rpcenv->get_user();

    my $nodename = PVE::INotify::nodename();

    my $vnets_cfg = PVE::Network::SDN::Vnets::config();
    my $zones_cfg = PVE::Network::SDN::Zones::config();

    my @vnetids = PVE::Network::SDN::Vnets::sdn_vnets_ids($vnets_cfg);

    my $vnets = {};

    foreach my $vnetid (@vnetids) {

	my $vnet = PVE::Network::SDN::Vnets::sdn_vnets_config($vnets_cfg, $vnetid);
	my $zoneid = $vnet->{zone};
	my $privs = [ 'SDN.Audit', 'SDN.Allocate' ];

	next if !$zoneid;
	next if !$rpcenv->check_any($authuser, "/sdn/zones/$zoneid", $privs, 1);

	my $zone_config = PVE::Network::SDN::Zones::sdn_zones_config($zones_cfg, $zoneid);

	next if defined($zone_config->{nodes}) && !$zone_config->{nodes}->{$nodename};
	$vnets->{$vnetid} = { type => 'vnet', active => '1' };
    }

    return $vnets;
}

1;

