#!/usr/bin/env bash
# Общие функции: «ВМ» (netns vm, 10.200.0.1) и «другая машина» (netns client, 10.200.0.2),
# соединённые veth-парой. Правила iptables применяются только внутри netns vm,
# поэтому сеть самого раннера не затрагивается.
VM_NS="vm"
CLIENT_NS="client"
VM_IP="10.200.0.1"
CLIENT_IP="10.200.0.2"
OTHER_IP="10.200.0.3"

vm() { sudo ip netns exec "$VM_NS" "$@"; }
client() { sudo ip netns exec "$CLIENT_NS" "$@"; }

# Печатает команду в стиле терминала и выполняет её в netns vm.
run_vm() {
  echo "vm\$ sudo $*"
  vm "$@" 2>&1 || true
  echo
}

setup_netns() {
  cleanup_netns
  sudo ip netns add "$VM_NS"
  sudo ip netns add "$CLIENT_NS"
  sudo ip link add veth-vm type veth peer name veth-client
  sudo ip link set veth-vm netns "$VM_NS"
  sudo ip link set veth-client netns "$CLIENT_NS"
  vm ip addr add "$VM_IP/24" dev veth-vm
  client ip addr add "$CLIENT_IP/24" dev veth-client
  client ip addr add "$OTHER_IP/24" dev veth-client
  vm ip link set lo up
  vm ip link set veth-vm up
  client ip link set lo up
  client ip link set veth-client up
}

cleanup_netns() {
  local ns pid
  for ns in "$VM_NS" "$CLIENT_NS"; do
    for pid in $(sudo ip netns pids "$ns" 2>/dev/null); do
      sudo kill "$pid" 2>/dev/null || true
    done
  done
  sudo ip netns del "$VM_NS" 2>/dev/null || true
  sudo ip netns del "$CLIENT_NS" 2>/dev/null || true
}
