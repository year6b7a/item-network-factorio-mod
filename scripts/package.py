"""A simple script to package the project"""
import json
from subprocess import Popen


def main():
    mod_name = "item-network"

    run_cmd(["rm", "-rf", "build"])
    run_cmd(["mkdir", "build"])
    run_cmd(["mkdir", "build/temp_folder"])

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
    run_cmd(["cp", "-r", *paths_to_copy, "build/temp_folder"])

    with open("info.json") as fid:
        mod_info = json.load(fid)
    mod_name = mod_info["name"]

    run_cmd(["zip", "-r", f"../{mod_name}.zip", "."], cwd="build/temp_folder")


def run_cmd(cmd, cwd=None):
    proc = Popen(cmd, cwd=cwd)
    assert proc.wait() == 0, f"Command {cmd} failed."


if __name__ == "__main__":
    main()
