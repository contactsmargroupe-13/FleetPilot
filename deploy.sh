#!/bin/bash
set -e
cd "$(dirname "$0")/fleetpilot_app"
echo ">> Flutter build web..."
flutter build web --release
echo ">> Deploy Firebase Hosting..."
firebase deploy --only hosting
echo ">> Deploye avec succes !"
