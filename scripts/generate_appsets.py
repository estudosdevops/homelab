#!/usr/bin/env python3
"""Gera um ApplicationSet por addon a partir de templates/appset.yaml.j2.

Uso: python3 generate_appsets.py [addon_name] [--apply]
"""
import subprocess
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader

REPO_URL = "https://github.com/estudosdevops/homelab.git"
TARGET_REVISION = "main"

REPO_ROOT = Path(
    subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip()
)
ADDONS_DIR = REPO_ROOT / "kubernetes" / "addons"
TEMPLATE_DIR = ADDONS_DIR / "templates"
OUTPUT_DIR = REPO_ROOT  / "kubernetes" / "addons" / ".generated" / "appsets"


def render(template, name, cfg):
    retry = cfg.get("retry")
    retry_yaml = ""
    if retry:
        lines = yaml.dump(retry, sort_keys=False).rstrip().splitlines()
        retry_yaml = "\n".join(" " * 10 + l for l in lines)

    return template.render(
        addon_name=name,
        addon_namespace=cfg.get("namespace", "default"),
        repo_url=REPO_URL,
        target_revision=TARGET_REVISION,
        annotations=cfg.get("annotations"),
        extra_sync_options=cfg.get("extraSyncOptions"),
        retry=retry,
        retry_yaml=retry_yaml,
    )


def main():
    args = sys.argv[1:]
    apply = "--apply" in args
    addon_filter = next((a for a in args if not a.startswith("-")), None)

    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR), trim_blocks=True, lstrip_blocks=True)
    template = env.get_template("appset.yaml.j2")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for config_path in sorted(ADDONS_DIR.glob("*/config.yaml")):
        cfg = yaml.safe_load(config_path.read_text()) or {}
        name = cfg.get("name", config_path.parent.name)
        if addon_filter and addon_filter != name:
            continue

        rendered = render(template, name, cfg)
        yaml.safe_load(rendered)  # falha rápido se o YAML sair inválido

        out_path = OUTPUT_DIR / f"{name}.yaml"
        out_path.write_text(rendered)
        print(f"[OK] {name} -> {out_path}")

        if apply:
            subprocess.run(["kubectl", "apply", "-f", "-"], input=rendered, text=True, check=True)


if __name__ == "__main__":
    main()
