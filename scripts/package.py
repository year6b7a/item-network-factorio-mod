"""A simple script to package the project"""
import json
from subprocess import Popen


def main():
    with open("info.json") as fid:
        mod_info = json.load(fid)
    mod_name = mod_info["name"]
    mod_version = mod_info["version"]
    full_mod_name = f"{mod_name}_{mod_version}"

    contents_path = f"build/zip_contents/{full_mod_name}"

    run_cmd(["rm", "-rf", "build"])
    run_cmd(["mkdir", "build"])
    run_cmd(["mkdir", "build/zip_contents"])
    run_cmd(["mkdir", contents_path])

    paths_to_copy = [
        "graphics",
        "locale",
        "constants.lua",
        "control.lua",
        "data-final-fixes.lua",
        "data.lua",
        "info.json",
        "NetworkChest.lua",
        "Paths.lua",
        "Queue.lua",
        "thumbnail.png",
    ]
    run_cmd(["cp", "-r", *paths_to_copy, contents_path])
    run_cmd(
        ["zip", "-r", f"../{full_mod_name}.zip", "."],
        cwd="build/zip_contents",
    )


def run_cmd(cmd, cwd=None):
    proc = Popen(cmd, cwd=cwd)
    assert proc.wait() == 0, f"Command {cmd} failed."


if __name__ == "__main__":
    main()
