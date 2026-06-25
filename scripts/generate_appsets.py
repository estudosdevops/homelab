#!/usr/bin/env python3
"""
Generate ApplicationSet per addon (co-located in addon directory).

Usage:
  python3 generate_appsets.py [addon]
  python3 generate_appsets.py [addon] --apply
"""

import os
import subprocess
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


REPO_URL = "https://github.com/estudosdevops/homelab.git"


# ---------------------------
# git helpers (DRY)
# ---------------------------

def run(cmd: list[str]) -> str:
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def repo_root() -> Path:
    return Path(run(["git", "rev-parse", "--show-toplevel"]))


def current_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"])


def target_revision() -> str:
    env = os.getenv("TARGET_REVISION")
    if env:
        return env

    branch = current_branch()
    return "main" if branch == "HEAD" else branch


# ---------------------------
# paths
# ---------------------------

ROOT = repo_root()

ADDONS_DIR = ROOT / "kubernetes" / "addons"
TEMPLATE_DIR = ADDONS_DIR / "templates"


# ---------------------------
# jinja
# ---------------------------

def get_template():
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    return env.get_template("appset.yaml.j2")


def build_retry_yaml(retry: dict | None) -> str:
    if not retry:
        return ""

    return "\n".join(
        " " * 10 + line
        for line in yaml.dump(retry, sort_keys=False).splitlines()
    )


def render(template, addon: str, cfg: dict) -> str:
    return template.render(
        addon_name=addon,
        addon_namespace=cfg.get("namespace", "default"),
        repo_url=REPO_URL,
        target_revision=target_revision(),
        annotations=cfg.get("annotations"),
        extra_sync_options=cfg.get("extraSyncOptions"),
        retry=cfg.get("retry"),
        retry_yaml=build_retry_yaml(cfg.get("retry")),
    )


# ---------------------------
# core
# ---------------------------

def addon_dir(name: str) -> Path:
    return ADDONS_DIR / name


def output_file(name: str) -> Path:
    return addon_dir(name) / "appset.yaml"


def generate(addon_path: Path, template):
    cfg = yaml.safe_load((addon_path / "config.yaml").read_text()) or {}

    addon_name = cfg.get("name", addon_path.name)

    rendered = render(template, addon_name, cfg)

    # validate YAML early
    yaml.safe_load(rendered)

    out = output_file(addon_path.name)
    out.write_text(rendered)

    print(f"[OK] {addon_path.name} -> {out}")


    return rendered


def apply(manifest: str):
    subprocess.run(
        ["kubectl", "apply", "-f", "-"],
        input=manifest,
        text=True,
        check=True,
    )


def main():
    args = sys.argv[1:]

    apply_flag = "--apply" in args
    addon_filter = next((a for a in args if not a.startswith("-")), None)

    template = get_template()

    for addon in sorted(ADDONS_DIR.iterdir()):
        if not addon.is_dir():
            continue

        if addon.name == "templates":
            continue

        cfg_file = addon / "config.yaml"
        if not cfg_file.exists():
            continue

        if addon_filter and addon_filter != addon.name:
            continue

        manifest = generate(addon, template)

        if apply_flag:
            apply(manifest)


if __name__ == "__main__":
    main()
