#!/bin/bash
echo "=== Checking Flask app logs ==="
sudo journalctl -u monitoring -n 50 --no-pager

echo ""
echo "=== Checking nginx access logs (last 10 lines) ==="
sudo tail -10 /var/log/nginx/access.log

echo ""
echo "=== Checking nginx error logs (last 10 lines) ==="
sudo tail -10 /var/log/nginx/error.log
