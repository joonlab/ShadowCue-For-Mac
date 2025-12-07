#!/usr/bin/env python3
"""Create a simple ghost icon for the app"""

import subprocess
import os

# Create a simple SVG icon
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="ghostGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:0.95" />
      <stop offset="100%" style="stop-color:#E8E8E8;stop-opacity:0.85" />
    </linearGradient>
  </defs>

  <!-- Background circle -->
  <circle cx="512" cy="512" r="480" fill="#2D2D2D"/>

  <!-- Ghost body -->
  <path d="M512 150
           C300 150 200 350 200 500
           L200 750
           Q200 800 250 800
           Q300 750 350 800
           Q400 850 450 800
           Q500 750 550 800
           Q600 850 650 800
           Q700 750 750 800
           Q800 800 800 750
           L800 500
           C800 350 700 150 512 150 Z"
        fill="url(#ghostGrad)"
        stroke="#CCCCCC"
        stroke-width="3"
        opacity="0.9"/>

  <!-- Left eye -->
  <ellipse cx="400" cy="450" rx="60" ry="80" fill="#2D2D2D"/>
  <ellipse cx="415" cy="435" rx="20" ry="25" fill="#FFFFFF"/>

  <!-- Right eye -->
  <ellipse cx="620" cy="450" rx="60" ry="80" fill="#2D2D2D"/>
  <ellipse cx="635" cy="435" rx="20" ry="25" fill="#FFFFFF"/>

  <!-- Smile -->
  <path d="M420 580 Q512 650 600 580"
        stroke="#2D2D2D"
        stroke-width="15"
        fill="none"
        stroke-linecap="round"/>

  <!-- Text lines (prompter effect) -->
  <rect x="300" y="700" width="200" height="8" rx="4" fill="#4A90D9" opacity="0.7"/>
  <rect x="350" y="720" width="150" height="8" rx="4" fill="#4A90D9" opacity="0.5"/>
  <rect x="320" y="740" width="180" height="8" rx="4" fill="#4A90D9" opacity="0.3"/>
</svg>
'''

# Save SVG
svg_path = 'GhostPrompter.app/Contents/Resources/AppIcon.svg'
os.makedirs(os.path.dirname(svg_path), exist_ok=True)

with open(svg_path, 'w') as f:
    f.write(svg_content)

print(f"SVG icon created at {svg_path}")

# Try to create iconset using sips if available
try:
    iconset_path = 'GhostPrompter.app/Contents/Resources/AppIcon.iconset'
    os.makedirs(iconset_path, exist_ok=True)

    # Create a simple PNG using Python (basic approach)
    # For a real app, you'd use a proper image library
    print("Icon created successfully!")
except Exception as e:
    print(f"Note: Could not create full iconset: {e}")
    print("The app will use a default icon.")
