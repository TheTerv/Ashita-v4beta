#!/usr/bin/env python3
"""
XivParty Texture Resizer for Ashita v4

D3D8 requires Power-Of-Two (POW2) texture dimensions.
This script resizes all XivParty PNG assets to the nearest POW2 size
by STRETCHING the content to fill the POW2 dimensions.

Why stretch instead of pad?
When Ashita's primitives render a texture, they stretch it to fit the
specified width/height. If we padded 377x21 to 512x32 and then rendered
at 377x21, the content would appear squished. By stretching to POW2,
the reverse scaling during rendering restores the original aspect ratio.

Requirements:
    pip install Pillow

Usage:
    python resize_textures.py

The script will:
1. Backup original images to a 'backup_npot' folder
2. Stretch all NPOT images to POW2 dimensions
3. Report what was changed
"""

import os
import shutil
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required. Install with: pip install Pillow")
    exit(1)


def next_pow2(n):
    """Return the next power of 2 >= n"""
    p = 1
    while p < n:
        p *= 2
    return p


def is_pow2(n):
    """Check if n is a power of 2"""
    return n > 0 and (n & (n - 1)) == 0


def resize_to_pow2(img_path, backup_dir):
    """
    Resize an image to POW2 dimensions if needed.
    STRETCHES the content to fill POW2 dimensions.

    Why stretch instead of pad?
    D3D8 primitives will stretch the texture to fit the specified width/height.
    If we PAD to 512x32 but render at 377x21, the content would be squished.
    By STRETCHING to 512x32, when rendered at 377x21, the scaling reverses
    and the content appears at the correct size with minimal distortion.

    Returns (was_resized, original_size, new_size)
    """
    img = Image.open(img_path)
    orig_width, orig_height = img.size

    # Check if already POW2
    if is_pow2(orig_width) and is_pow2(orig_height):
        return False, (orig_width, orig_height), (orig_width, orig_height)

    # Calculate POW2 dimensions
    new_width = next_pow2(orig_width)
    new_height = next_pow2(orig_height)

    # Backup original
    rel_path = os.path.relpath(img_path, start=os.path.dirname(backup_dir))
    backup_path = os.path.join(backup_dir, rel_path)
    os.makedirs(os.path.dirname(backup_path), exist_ok=True)
    shutil.copy2(img_path, backup_path)

    # Ensure RGBA mode
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # STRETCH the image to POW2 dimensions using high-quality resampling
    new_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Save
    new_img.save(img_path, 'PNG')

    return True, (orig_width, orig_height), (new_width, new_height)


def main():
    # Get the script directory (should be in xivparty folder)
    script_dir = Path(__file__).parent
    assets_dir = script_dir / "assets"

    if not assets_dir.exists():
        print(f"ERROR: Assets directory not found: {assets_dir}")
        exit(1)

    # Create backup directory
    backup_dir = script_dir / "backup_npot"
    backup_dir.mkdir(exist_ok=True)

    print("XivParty Texture Resizer")
    print("=" * 50)
    print(f"Assets directory: {assets_dir}")
    print(f"Backup directory: {backup_dir}")
    print()

    # Find all PNG files
    png_files = list(assets_dir.rglob("*.png"))
    print(f"Found {len(png_files)} PNG files")
    print()

    resized_count = 0
    skipped_count = 0
    errors = []

    for png_path in png_files:
        try:
            was_resized, orig_size, new_size = resize_to_pow2(str(png_path), str(backup_dir))

            rel_path = png_path.relative_to(assets_dir)
            if was_resized:
                print(f"[RESIZED] {rel_path}: {orig_size[0]}x{orig_size[1]} -> {new_size[0]}x{new_size[1]}")
                resized_count += 1
            else:
                skipped_count += 1
                # Uncomment to see skipped files:
                # print(f"[OK]      {rel_path}: {orig_size[0]}x{orig_size[1]} (already POW2)")
        except Exception as e:
            errors.append((png_path, str(e)))
            print(f"[ERROR]   {png_path}: {e}")

    print()
    print("=" * 50)
    print(f"Summary:")
    print(f"  Resized: {resized_count}")
    print(f"  Skipped (already POW2): {skipped_count}")
    print(f"  Errors: {len(errors)}")
    print()

    if resized_count > 0:
        print(f"Original files backed up to: {backup_dir}")
        print()
        print("IMPORTANT: After resizing, reload the addon in-game:")
        print("  /addon reload xivparty")
    else:
        print("No files needed resizing.")


if __name__ == "__main__":
    main()
