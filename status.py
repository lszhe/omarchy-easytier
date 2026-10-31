#!/usr/bin/env python3
"""Read only the public status fields needed by the panel; never emit config."""
import json
import shutil
import subprocess
import sys


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=4, check=True).stdout


def read_service(name):
    if not name or not all(c.isascii() and (c.isalnum() or c in '_.@-') for c in name) or not name.endswith('.service'):
        return 'invalid'
    try:
        result = run('systemctl', 'show', '--property=LoadState', '--property=ActiveState', '--', name)
        fields = dict(line.split('=', 1) for line in result.splitlines() if '=' in line)
        if fields.get('LoadState') != 'loaded':
            return 'missing'
        return fields.get('ActiveState', 'unknown')
    except (subprocess.SubprocessError, OSError, ValueError):
        return 'unknown'


def read_status(service_name='easytier-omarchy.service'):
    service = read_service(service_name)
    cli = shutil.which("easytier-cli")
    if not cli:
        return {"state": "missing", "message": "找不到 easytier-cli", "service": service, "peers": []}
    try:
        node = json.loads(run(cli, "-o", "json", "node"))
        peers = json.loads(run(cli, "-o", "json", "peer"))
        if not isinstance(node, dict) or not isinstance(peers, list):
            raise ValueError("unexpected response")
        clean = []
        for peer in peers:
            if not isinstance(peer, dict):
                continue
            clean.append({
                "name": str(peer.get("hostname") or "未知节点"),
                "ip": str(peer.get("ipv4") or "").split('/')[0],
                "latency": str(peer.get("lat_ms") if peer.get("lat_ms") is not None else ""),
                "protocol": str(peer.get("tunnel_proto") or ""),
            })
        return {"state": "ready", "message": "CLI 已连接到后台", "name": str(node.get("hostname") or "本机"),
                "ip": str(node.get("ipv4_addr") or "").split('/')[0], "service": service, "peers": clean}
    except (subprocess.SubprocessError, OSError, ValueError, TypeError):
        message = '组网服务已停止' if service in ('inactive', 'failed') else '无法连接 EasyTier 后台，请检查服务'
        return {"state": "unavailable", "message": message, "service": service, "peers": []}


if __name__ == "__main__":
    json.dump(read_status(sys.argv[1] if len(sys.argv) > 1 else 'easytier-omarchy.service'), sys.stdout, ensure_ascii=False)
    print()
