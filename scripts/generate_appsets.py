#!/usr/bin/env python3
"""
Gera um ApplicationSet por addon a partir de templates/appset.yaml.j2.

Uso:
    python3 generate_appsets.py
    python3 generate_appsets.py cert-manager
    python3 generate_appsets.py cert-manager --apply

Override da revisão:
    TARGET_REVISION=feature/cert-manager python3 generate_appsets.py
"""

import os
import subprocess
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader

REPO_URL = "https://github.com/estudosdevops/homelab.git"


def run_command(cmd: list[str]) -> str:
    """Executa comando e retorna stdout."""
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def get_repo_root() -> Path:
    """Retorna diretório raiz do repositório."""
    return Path(run_command(["git", "rev-parse", "--show-toplevel"]))


def get_current_branch() -> str:
    """Retorna a branch atual."""
    return run_command(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"]
    )


def get_target_revision() -> str:
    """
    Prioridade:
    1. TARGET_REVISION env
    2. Branch atual
    3. main (fallback)
    """

    if env_revision := os.getenv("TARGET_REVISION"):
        return env_revision

    try:
        branch = get_current_branch()

        if branch == "HEAD":
            return "main"

        return f"refs/heads/{branch}"

    except Exception:
        return "main"


REPO_ROOT = get_repo_root()

ADDONS_DIR = REPO_ROOT / "kubernetes" / "addons"
TEMPLATE_DIR = ADDONS_DIR / "templates"
OUTPUT_DIR = ADDONS_DIR / ".generated" / "appsets"

TARGET_REVISION = get_target_revision()


def build_retry_yaml(retry_cfg: dict | None) -> str:
    """Converte retry config para YAML indentado."""
    if not retry_cfg:
        return ""

    lines = yaml.dump(
        retry_cfg,
        sort_keys=False,
    ).rstrip().splitlines()

    return "\n".join(
        f"{' ' * 10}{line}"
        for line in lines
    )


def render(template, addon_name: str, cfg: dict) -> str:
    """Renderiza template Jinja."""

    return template.render(
        addon_name=addon_name,
        addon_namespace=cfg.get("namespace", "default"),
        repo_url=REPO_URL,
        target_revision=TARGET_REVISION,
        annotations=cfg.get("annotations"),
        extra_sync_options=cfg.get("extraSyncOptions"),
        retry=cfg.get("retry"),
        retry_yaml=build_retry_yaml(cfg.get("retry")),
    )


def get_template():
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        trim_blocks=True,
        lstrip_blocks=True,
    )

    return env.get_template("appset.yaml.j2")


def generate_appset(config_path: Path, template):
    cfg = yaml.safe_load(
        config_path.read_text()
    ) or {}

    addon_name = cfg.get(
        "name",
        config_path.parent.name,
    )

    rendered = render(
        template,
        addon_name,
        cfg,
    )

    yaml.safe_load(rendered)

    out_path = OUTPUT_DIR / f"{addon_name}.yaml"
    out_path.write_text(rendered)

    print(
        f"[OK] {addon_name} "
        f"(revision={TARGET_REVISION}) "
        f"-> {out_path}"
    )

    return rendered


def apply_manifest(manifest: str):
    subprocess.run(
        ["kubectl", "apply", "-f", "-"],
        input=manifest,
        text=True,
        check=True,
    )


def main():
    args = sys.argv[1:]

    apply = "--apply" in args

    addon_filter = next(
        (arg for arg in args if not arg.startswith("-")),
        None,
    )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    template = get_template()

    for config_path in sorted(
        ADDONS_DIR.glob("*/config.yaml")
    ):
        cfg = yaml.safe_load(
            config_path.read_text()
        ) or {}

        addon_name = cfg.get(
            "name",
            config_path.parent.name,
        )

        if addon_filter and addon_filter != addon_name:
            continue

        manifest = generate_appset(
            config_path,
            template,
        )

        if apply:
            apply_manifest(manifest)


if __name__ == "__main__":
    main()
