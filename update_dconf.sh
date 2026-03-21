#!/bin/bash
set -e

echo "Updating dconf databases..."

# Update the system databases
dconf update

echo "Dconf databases updated."