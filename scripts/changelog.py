from collections import defaultdict
import datetime
from typing import Optional


def get_changelog():
    cl = Changelog()

    v = cl.version()
    v.feature(
        "Enhanced copy-paste behavior between Network Chests and assemblers. If you copy from a Network Chest and paste on an assembler, it add requests for recipe ingredients for the recipe. If you copy from an assembler and paste on a Network Chest, it will provide recipe products from the chest."
    )
    v.change(
        "Changed network chest copy-past behavior so subsequent copies and pastes to the same Network Chest append items rather than overrite items. This should make it easier to have one chest supply multiple assemblers."
    )

    v = cl.version((0, 7, 5), datetime.date(2023, 8, 28))
    v.fix("Fixed bug where using ReStack to lower stack size would crash.")
    v.fix("Fixed bug where unable to set large buffers using UI.")
    v.feature(
        'Added "No Limit" option when providing items from Network Chests and Tanks.'
    )

    v = cl.version((0, 7, 4), datetime.date(2023, 8, 20))
    v.feature("Added setting to change the number of updates per tick.")
    v.feature(
        "Added ability to deposit and retrieve items in the Network View. Thanks to bengardner for implementing this feature!"
    )

    v = cl.version((0, 7, 3), datetime.date(2023, 8, 18))
    v.fix("Hopefully fixed bug when viewing shortages tab.")

    v = cl.version((0, 7, 2), datetime.date(2023, 8, 15))
    v.fix(
        "Requests for constructing missing items in the construction zone of roboports and players will now be satisfied. Before, only request for missing items in the logistic zone of roboports were satisfied. Thanks to bengardner for implementing this feature!"
    )
    v.feature(
        "Added support for rails, cliff explosives, stone brick paths, repair packs and modules to be automatically supplied to logistic networks. Thanks to bengardner for implementing this feature!"
    )
    v.fix(
        "Fixed the bug where the shortages tab would crash when there are invalid item names."
    )

    v = cl.version((0, 7, 1), datetime.date(2023, 8, 11))
    v.fix("Removed flib reference and made the Network View header draggable.")

    v = cl.version((0, 7, 0), datetime.date(2023, 8, 11))
    v.feature(
        'Added a new "Shortages" tab to the Network View that displays item shortages to help find bottlenecks. Big thanks to bengardner for implementing this feature!'
    )
    v.feature(
        "Added support for supplying Spitertron logistic requests from the Item Network. Big thanks to bengardner for implementing this feature!"
    )
    v.feature(
        "Added support for automatically transferring items to a logistic network if it is missing items to construct ghosts or upgrades. Big thanks to bengardner for implementing this feature!"
    )
    v.change(
        "The Network View now has tabs instead of radio buttons for the each view. Big thanks to bengardner for implementing this feature!"
    )

    v = cl.version((0, 6, 0), datetime.date(2023, 8, 8))
    v.feature(
        "Logistic Requester and Buffer chests now pull items from the Item Network. This can be disabled in settings. Huge thanks to bengardner for the idea and implementation, as well as being the first external contributor to this mod. Thanks!"
    )
    v.change("Increased Network Tank health from 10 -> 200.")

    v = cl.version((0, 5, 0), datetime.date(2023, 7, 29))
    v.feature(
        "Network Tanks now support fluids with different temperatures! Make sure that if you provide fluids at non-default temperatures (like steam) you update all requester tanks with the new temperature. You can use the Network View to see which fluids are in your network to help debug."
    )
    v.feature("Added tooltips to items and fluids in the Network View.")
    v.change(
        'Network Tanks that are configured as Providers now only need "limit" and will try to push any fluids into the network.'
    )
    v.change(
        "Network Tanks now require a temperature when pulling fluids out of the network."
    )

    v = cl.version((0, 4, 0), datetime.date(2023, 7, 28))
    v.change(
        "Changed queue update logic to be less random and more consistent. This should help smooth out performance, especially for factories with a ton of Network Chests and Tanks."
    )

    v = cl.version((0, 3, 7), datetime.date(2023, 7, 27))
    v.fix(
        'Fixed bug where interacting with the mod before the first game tick would crash. This was easy to reproduce in the "Map Editor" mode.'
    )

    v = cl.version((0, 3, 6), datetime.date(2023, 7, 22))
    v.fix(
        "Fixed bug where destroying Network Chests and Tanks would delete Buffer contents. Contents are now automatically pushed into the network."
    )
    v.fix(
        "Fixed bug where replacing ghosts of destroyed Network Chests and Tanks would not set previous requests."
    )

    v = cl.version((0, 3, 5), datetime.date(2023, 7, 19))
    v.fix("Fixed crash when deleting a Network Chest with the UI open.")

    v = cl.version((0, 3, 4), datetime.date(2023, 7, 12))
    v.fix("Fixed bug where on_entity_cloned handler did not register network tanks.")
    v.change(
        "Increased loader speed to 360 items/sec. No issues seen in tests on existing factories but log a bug if this causes issues."
    )

    v = cl.version((0, 3, 3), datetime.date(2023, 7, 5))
    v.fix(
        "Fixed bug where swapping between 'Request' and 'Provide' without a limit would crash."
    )
    v.feature("Added ability to copy-paste settings from one Network Tank to another.")

    v = cl.version((0, 3, 2), datetime.date(2023, 7, 4))
    v.change('Swapped "Request" and "Provide" to be consistent with logistics chests.')
    v.change("Removed readme pictures to reduce zip size from 14Mb -> 500Kb.")
    v.fix(
        "Fixed bug where Network Tanks and Loaders could not be placed in space in Space Exploration."
    )
    v.change(
        "Changed to update limit when switching between Request and Provide in Network Chests."
    )

    v = cl.version((0, 3, 1), datetime.date(2023, 7, 2))
    v.fix(
        "Fixed to_be_deconstructed bug where deleting and then canceling deletion would stop updating chest."
    )
    v.major_feature("Added Network Tanks to transport fuids.")
    v.feature("Added refresh button to network view.")

    v = cl.version((0, 2, 2), datetime.date(2023, 6, 26))
    v.feature(
        "Added player setting to disable logistic requests and trash from the network."
    )
    v.feature("Added setting to configure default stack size on assembler paste.")
    v.fix("Fixed on_entity_cloned handler.")

    v = cl.version((0, 2, 1), datetime.date(2023, 6, 14))
    v.fix("Fixed crash when updating blueprints.")
    v.fix("Fixed potential UI bug on multiplayer.")
    v.feature("Added first version of network view UI to view network contents.")

    v = cl.version((0, 2, 0), datetime.date(2023, 6, 10))
    v.fix(
        "Fixed multiplayer UI bug by refactoring UI to store player states separately."
    )
    v.fix("Fixed bug where pasting a deleted entity would remove requests.")
    v.feature("Added ability to press Enter to submit modals.")

    v = cl.version((0, 1, 0), datetime.date(2023, 6, 6))
    v.fix("Renamed Give -> Request and Take -> Provide.")
    v.change("Increased loader speed.")
    v.feature("Added support for player logistics.")

    return cl


class Changelog:
    def __init__(self):
        self.__versions: list[ChangelogVersion] = []

    def version(
        self,
        version: tuple[int] = (999, 999, 999),
        date: datetime.date = datetime.date(1000, 1, 1),
    ):
        # call with no arguments to create the unreleased changelog
        ver = ChangelogVersion(version, date)
        self.__versions.append(ver)
        return ver

    def to_str(self):
        lines = []
        versions = sorted(
            self.__versions, key=lambda version: version.version, reverse=True
        )
        for ver in versions:
            lines.extend(ver.get_lines())
        return "".join(line + "\n" for line in lines)

    def get_most_recent_version(self):
        return max(version.version for version in self.__versions)


class ChangelogVersion:
    def __init__(self, version: tuple[str], date: Optional[datetime.date]):
        self.version = version
        self.__date = date
        self.__parts = []

    def __add_part(self, category: str, msg: str):
        assert category in CATEGORY_TO_IDX_MAP
        self.__parts.append((category, msg))

    def major_feature(self, msg: str):
        self.__add_part("Major Features", msg)

    def feature(self, msg: str):
        self.__add_part("Features", msg)

    def fix(self, msg: str):
        self.__add_part("Bugfixes", msg)

    def change(self, msg: str):
        self.__add_part("Changes", msg)

    def get_lines(self):
        assert self.version is not None
        assert self.__date is not None
        assert len(self.__parts) > 0
        lines = []
        lines.append("-" * 99)

        lines.append(f"Version: {self.version[0]}.{self.version[1]}.{self.version[2]}")
        lines.append(f"Date: {self.__date.strftime('%d. %m. %Y')}")

        groups = defaultdict(list)
        for category, msg in self.__parts:
            groups[category].append(msg)

        sorted_categories = sorted(
            groups, key=lambda category: CATEGORY_TO_IDX_MAP[category]
        )

        is_first = True
        for category in sorted_categories:
            if not is_first:
                lines.append("")
            messages = groups[category]
            lines.append(f"  {category}:")
            for msg in messages:
                assert msg.endswith(".") or msg.endswith("!")
                lines.append(f"    - {msg}")
            is_first = False

        return lines


CATEGORIES = [
    "Major Features",
    "Features",
    "Minor Features",
    "Graphics",
    "Sounds",
    "Optimizations",
    "Balancing",
    "Combat Balancing",
    "Circuit Network",
    "Changes",
    "Bugfixes",
    "Modding",
    "Scripting",
    "Gui",
    "Control",
    "Translation",
    "Debug",
    "Ease of use",
    "Info",
    "Locale",
]
CATEGORY_TO_IDX_MAP = {category: idx for idx, category in enumerate(CATEGORIES)}
