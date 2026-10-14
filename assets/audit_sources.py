#!/usr/bin/env python3
"""Inventory selected pinned artwork, with user-confirmed MIT permission.

The byte comparison is historical evidence, not a separate legal audit.
The user explicitly approved these selected Greg Flavored assets as MIT.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

GREG_REV = "ac6cafc3993c902e2ca95d85b501d3c7e172570c"
CC_REV = "c8b3f6af270cd74c7494e2bf45a9f377b90c9b29"
PACK = "resourcepack/refreshed/Computer Craft Greg Refreshed 1.20.1/assets/"
CC_ASSETS = "projects/common/src/main/resources/assets/"


def git(repo, *args):
    return subprocess.check_output(["git", "--no-optional-locks", "-c", "gc.auto=0", "-C", str(repo), *args])


def blob(repo, revision, path):
    return git(repo, "show", revision + ":" + path)


def inventory(repo, revision):
    return git(repo, "ls-tree", "-r", "--name-only", "-z", revision).decode().split("\0")[:-1]


def record(repo, revision, path):
    data = blob(repo, revision, path)
    result = {"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    if path.endswith(".png"):
        assert data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR"
        width, height, depth, color = struct.unpack(">IIBB", data[16:26])
        result["png"] = {"width": width, "height": height, "bit_depth": depth,
                         "color_type": color, "alpha_channel": color in (4, 6)}
    return result


def resource(identifier, kind, extension):
    namespace, name = identifier.split(":", 1) if ":" in identifier else ("minecraft", identifier)
    return namespace + "/" + kind + "/" + name + extension


def audit(greg, cc):
    paths = set(inventory(greg, GREG_REV))
    cc_paths = inventory(cc, CC_REV)
    # Compare Git blobs, not working-tree files or lossy decoded/re-encoded PNGs.
    cc_by_hash = {}
    for path in cc_paths:
        if path.startswith(CC_ASSETS) and path.endswith((".json", ".png", ".mcmeta")):
            digest = hashlib.sha256(blob(cc, CC_REV, path)).hexdigest()
            cc_by_hash.setdefault(digest, []).append(path)
    seeds = ["computercraft:block/computer_advanced_" + state
             for state in ("off", "on", "blinking")]
    seeds += sorted("computercraft:block/" + Path(p).stem for p in paths
                    if p.startswith(PACK + "computercraft/models/block/monitor_advanced")
                    and p.endswith(".json"))
    model_records = {}
    texture_ids = set()
    unresolved_parents = set()

    def resolve(identifier, chain=()):
        if identifier in chain:
            raise ValueError("cyclic model inheritance: " + identifier)
        path = PACK + resource(identifier, "models", ".json")
        if path not in paths:
            unresolved_parents.add(identifier)
            return {}, None
        data = json.loads(blob(greg, GREG_REV, path))
        textures, elements = {}, None
        if "parent" in data:
            textures, elements = resolve(data["parent"], chain + (identifier,))
        textures = {**textures, **data.get("textures", {})}
        elements = data.get("elements", elements)
        model_records[path] = {**record(greg, GREG_REV, path), "permission": "MIT-user-confirmed-selected-assets",
                               "parent": data.get("parent"),
                               "cc_exact_matches": cc_by_hash.get(record(greg, GREG_REV, path)["sha256"], [])}
        return textures, elements

    resolved = []
    for seed in seeds:
        textures, elements = resolve(seed)
        used = set()
        for element in elements or []:
            for face in element.get("faces", {}).values():
                target = face["texture"]
                seen = set()
                while target.startswith("#"):
                    if target in seen:
                        raise ValueError("cyclic texture alias: " + target)
                    seen.add(target)
                    target = textures[target[1:]]
                used.add(target)
        texture_ids.update(used)
        resolved.append({"model": seed, "used_face_textures": sorted(used),
                         "unused_bindings": {k: v for k, v in sorted(textures.items())
                                             if not v.startswith("#") and v not in used}})
    textures = []
    for identifier in sorted(texture_ids):
        path = PACK + resource(identifier, "textures", ".png")
        if path not in paths:
            textures.append({"resource": identifier, "path": path, "permission": "missing-input"})
            continue
        entry = {**record(greg, GREG_REV, path), "resource": identifier,
                 "permission": "MIT-user-confirmed-selected-assets", "origin": "selected Greg Flavored input",
                 "cc_exact_matches": cc_by_hash.get(record(greg, GREG_REV, path)["sha256"], [])}
        if path + ".mcmeta" in paths:
            entry["animation"] = record(greg, GREG_REV, path + ".mcmeta")
        textures.append(entry)
    return {
        "format_version": 1,
        "status": "selected-assets-approved",
        "purpose": "Pinned source inventory; output metadata is in manifest.json",
        "greg_flavored": {"repository": "https://github.com/BirbIrl/ComputerCraft-Greg-Flavored",
                          "revision": GREG_REV,
                          "evidence": [record(greg, GREG_REV, p) for p in ("LICENSE", "README.md")]},
        "cc_tweaked": {"repository": "https://github.com/cc-tweaked/CC-Tweaked", "revision": CC_REV,
                       "evidence": [record(cc, CC_REV, p) for p in ("LICENSES/LicenseRef-CCPL.txt", "REUSE.toml")]},
        "credited_projects_not_per_file_attribution": ["GregTech Refreshed", "GTCEu: Modern",
                                                       "GregTech Programmer Art", "CC: Tweaked"],
        "cleared_runtime_assets": sorted(model_records) + [r["path"] for r in textures],
        "distributed_derived_outputs": "See assets/manifest.json",
        "candidate_models": [model_records[p] for p in sorted(model_records)],
        "resolved_models": resolved,
        "candidate_textures": textures,
        "external_parent_references": sorted(unresolved_parents),
        "interpretation": "The user explicitly confirmed the specific selected Greg Flavored assets "
                          "are MIT, not CC:Tweaked assets, and approved their use. No separate legal "
                          "audit or permission letter was obtained. Unused inherited bindings are not selected inputs.",
        "glyphs": {"status": "independently-authored-see-manifest", "required_cell": [6, 9], "required_ascii": [32, 126],
                   "required_mosaic": [128, 159], "other_bytes": "outlined replacement box",
                   "excluded_input": "CC and Greg Flavored term_font.png; no font bytes imported"},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--greg-repo", required=True, type=Path)
    parser.add_argument("--cc-repo", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    data = audit(args.greg_repo, args.cc_repo)
    args.output.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"models": len(data["candidate_models"]),
                      "resolved_variants": len(data["resolved_models"]),
                      "textures": len(data["candidate_textures"]),
                      "cleared_runtime_assets": len(data["cleared_runtime_assets"]),
                      "status": data["status"]}, sort_keys=True))


if __name__ == "__main__":
    main()
