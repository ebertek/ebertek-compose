#!/bin/bash
sleep 10

ip link add macvlan1 link ovs_bond0 type macvlan mode bridge
ip addr add 10.4.21.1/32 dev macvlan1
ip link set macvlan1 up
ip route add 10.4.21.0/24 dev macvlan1
