#!/usr/bin/env python3
"""
Test script to serially benchmark FLUX.2 Klein 4B with TeaCache & PromptEmbedCache
on vLLM-Omni ROCm (AMD Strix Halo APU).

Tests:
1. Cold Text-to-Image generation (16:9, 768x432)
2. Warm Text-to-Image generation (Prompt Cache Hit, 768x432)
3. Text-to-Image generation (4:3, 768x576)
4. Image Edit / Inpainting (16:9, 768x432) using Test 1 output as reference
5. Image Edit / Inpainting (4:3, 768x576) using Test 3 output as reference

Saves generated images directly and logs timing statistics.
"""

import argparse
import base64
import json
import os
import struct
import sys
import time
from typing import Tuple

import requests

API_BASE = "http://192.168.2.7:30810"
MODEL_NAME = "black-forest-labs/FLUX.2-klein-4B"


def get_png_dimensions(data: bytes) -> Tuple[int, int]:
    """Extract width and height from PNG header bytes."""
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", data[16:24])
        return w, h
    return 0, 0


def generate_image(
    prompt: str,
    size: str,
    output_path: str,
) -> Tuple[float, int, int]:
    """Generate image via /v1/images/generations and save as PNG."""
    url = f"{API_BASE}/v1/images/generations"
    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "size": size,
        "n": 1,
        "response_format": "b64_json",
    }
    headers = {"Content-Type": "application/json"}

    start_time = time.perf_counter()
    resp = requests.post(url, json=payload, headers=headers, timeout=300)
    elapsed = time.perf_counter() - start_time

    if resp.status_code != 200:
        print(f"Error {resp.status_code}: {resp.text}")
        sys.exit(1)

    data = resp.json()
    b64_data = data["data"][0]["b64_json"]
    img_bytes = base64.b64decode(b64_data)
    with open(output_path, "wb") as f:
        f.write(img_bytes)
    w, h = get_png_dimensions(img_bytes)
    return elapsed, w, h


def edit_image(
    image_path: str,
    prompt: str,
    size: str,
    output_path: str,
) -> Tuple[float, int, int]:
    """Edit image via /v1/images/edits and save as PNG."""
    url = f"{API_BASE}/v1/images/edits"
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    files = {
        "image": (os.path.basename(image_path), image_bytes, "image/png"),
    }
    data = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "size": size,
        "response_format": "b64_json",
    }

    start_time = time.perf_counter()
    resp = requests.post(url, files=files, data=data, timeout=300)
    elapsed = time.perf_counter() - start_time

    if resp.status_code != 200:
        print(f"Error {resp.status_code}: {resp.text}")
        sys.exit(1)

    res_json = resp.json()
    b64_data = res_json["data"][0]["b64_json"]
    img_bytes = base64.b64decode(b64_data)
    with open(output_path, "wb") as f:
        f.write(img_bytes)
    w, h = get_png_dimensions(img_bytes)
    return elapsed, w, h


def main():
    parser = argparse.ArgumentParser(description="Serial benchmark for FLUX.2 Klein on vLLM-Omni")
    parser.add_argument(
        "--output-dir",
        default="/home/david/.gemini/antigravity-cli/brain/943d51d5-99c0-4ef3-8b0b-1a0b0f34e9e1",
        help="Directory to store generated images",
    )
    args = parser.parse_args()
    os.makedirs(args.output_dir, exist_ok=True)

    print("=" * 75)
    print("FLUX.2 Klein 4B Serial Benchmark (TeaCache + Prompt Cache)")
    print(f"API Target: {API_BASE}")
    print(f"Output Directory: {args.output_dir}")
    print("=" * 75)

    results = []

    # -------------------------------------------------------------
    # Test 1: Cold Text-to-Image (16:9 widescreen, 768x432)
    # -------------------------------------------------------------
    t1_prompt = "A tranquil Japanese zen garden with mossy stones, bamboo water fountain, and autumn maple leaves, cinematic morning light, photorealistic"
    t1_size = "768x432"
    t1_path = os.path.join(args.output_dir, "flux2_serial_1_zen_garden.png")
    print(f"\n[Test 1/5] Running Cold T2I (16:9: {t1_size})...")
    print(f"Prompt: {t1_prompt}")
    t1_time, t1_w, t1_h = generate_image(t1_prompt, t1_size, t1_path)
    print(f"-> Completed in {t1_time:.2f}s | Saved: {t1_path} ({t1_w}x{t1_h})")
    results.append({
        "test": "1. Cold T2I (16:9)",
        "prompt": t1_prompt,
        "size": f"{t1_w}x{t1_h}",
        "time": t1_time,
        "notes": "Cold run (TeaCache active, Prompt cache miss)",
        "image": t1_path,
    })

    # -------------------------------------------------------------
    # Test 2: Warm Text-to-Image (Prompt Cache Hit, 768x432)
    # -------------------------------------------------------------
    t2_path = os.path.join(args.output_dir, "flux2_serial_2_zen_garden_cached.png")
    print(f"\n[Test 2/5] Running Warm T2I (Exact duplicate prompt for Prompt Cache Hit)...")
    t2_time, t2_w, t2_h = generate_image(t1_prompt, t1_size, t2_path)
    print(f"-> Completed in {t2_time:.2f}s | Saved: {t2_path} ({t2_w}x{t2_h})")
    results.append({
        "test": "2. Warm T2I (Prompt Cache Hit)",
        "prompt": t1_prompt,
        "size": f"{t2_w}x{t2_h}",
        "time": t2_time,
        "notes": f"Prompt cache hit (delta: {t2_time - t1_time:+.2f}s)",
        "image": t2_path,
    })

    # -------------------------------------------------------------
    # Test 3: Text-to-Image (4:3 aspect ratio, 768x576)
    # -------------------------------------------------------------
    t3_prompt = "A futuristic hydroponic greenhouse with glowing purple and green flora under a glass dome on Mars, hyperdetailed 8k"
    t3_size = "768x576"
    t3_path = os.path.join(args.output_dir, "flux2_serial_3_mars_greenhouse_4_3.png")
    print(f"\n[Test 3/5] Running T2I (4:3: {t3_size})...")
    print(f"Prompt: {t3_prompt}")
    t3_time, t3_w, t3_h = generate_image(t3_prompt, t3_size, t3_path)
    print(f"-> Completed in {t3_time:.2f}s | Saved: {t3_path} ({t3_w}x{t3_h})")
    results.append({
        "test": "3. T2I (4:3 Aspect Ratio)",
        "prompt": t3_prompt,
        "size": f"{t3_w}x{t3_h}",
        "time": t3_time,
        "notes": "4:3 aspect ratio with TeaCache",
        "image": t3_path,
    })

    # -------------------------------------------------------------
    # Test 4: Image Edit (16:9, 768x432) using Test 1 output
    # -------------------------------------------------------------
    t4_prompt = "Add a cute red panda sitting on one of the mossy stones in the garden"
    t4_size = "768x432"
    t4_path = os.path.join(args.output_dir, "flux2_serial_4_zen_garden_edited.png")
    print(f"\n[Test 4/5] Running Image Edit on Test 1 (16:9: {t4_size})...")
    print(f"Prompt: {t4_prompt}")
    t4_time, t4_w, t4_h = edit_image(t1_path, t4_prompt, t4_size, t4_path)
    print(f"-> Completed in {t4_time:.2f}s | Saved: {t4_path} ({t4_w}x{t4_h})")
    results.append({
        "test": "4. Image Edit (16:9)",
        "prompt": t4_prompt,
        "size": f"{t4_w}x{t4_h}",
        "time": t4_time,
        "notes": "Inpainting with concatenated latents & TeaCache",
        "image": t4_path,
    })

    # -------------------------------------------------------------
    # Test 5: Image Edit (4:3, 768x576) using Test 3 output
    # -------------------------------------------------------------
    t5_prompt = "Add an astronaut in an orange exploration suit tending to the glowing hydroponic plants"
    t5_size = "768x576"
    t5_path = os.path.join(args.output_dir, "flux2_serial_5_mars_edited_astronaut.png")
    print(f"\n[Test 5/5] Running Image Edit on Test 3 (4:3: {t5_size})...")
    print(f"Prompt: {t5_prompt}")
    t5_time, t5_w, t5_h = edit_image(t3_path, t5_prompt, t5_size, t5_path)
    print(f"-> Completed in {t5_time:.2f}s | Saved: {t5_path} ({t5_w}x{t5_h})")
    results.append({
        "test": "5. Image Edit (4:3)",
        "prompt": t5_prompt,
        "size": f"{t5_w}x{t5_h}",
        "time": t5_time,
        "notes": "4:3 Inpainting with TeaCache",
        "image": t5_path,
    })

    # -------------------------------------------------------------
    # Summary Table
    # -------------------------------------------------------------
    print("\n" + "=" * 80)
    print(f"{'Test':<30} | {'Size':<9} | {'Latency':<8} | {'Notes'}")
    print("-" * 80)
    for r in results:
        print(f"{r['test']:<30} | {r['size']:<9} | {r['time']:>6.2f}s | {r['notes']}")
    print("=" * 80)


if __name__ == "__main__":
    main()
