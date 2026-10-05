"""Build numbers the appcast advertises must match CURRENT_PROJECT_VERSION
and keep Sparkle's numeric ordering in release order."""

import importlib.util
from pathlib import Path

import pytest

_SCRIPT = Path(__file__).resolve().parents[1] / "generate-appcast.py"
_spec = importlib.util.spec_from_file_location("generate_appcast", _SCRIPT)
generate_appcast = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(generate_appcast)


@pytest.mark.parametrize(
    "tag, expected",
    [
        # Every release so far keeps the build number it shipped with.
        ("v1.7.0-amphetamine.2", "1070002"),
        ("v1.7.0-amphetamine.4", "1070004"),
        ("v1.7.0-amphetamine.5", "1070005"),
        ("v1.7.0-amphetamine.10", "1070010"),
        ("v1.7.1-amphetamine.1", "1070101"),
        ("v1.8.0-amphetamine.1", "1080001"),
    ],
)
def test_build_number(tag, expected):
    assert generate_appcast.parse_build_number(tag, "") == expected


def test_build_numbers_increase_in_release_order():
    tags = [
        "v1.7.0-amphetamine.9",
        "v1.7.0-amphetamine.10",
        "v1.7.0-amphetamine.11",
        "v1.7.1-amphetamine.1",
        "v1.7.10-amphetamine.1",
        "v1.8.0-amphetamine.1",
        "v2.0.0-amphetamine.1",
    ]
    numbers = [int(generate_appcast.parse_build_number(t, "")) for t in tags]
    assert numbers == sorted(numbers)
    assert len(set(numbers)) == len(numbers)


def test_build_number_matches_xcconfig_for_its_release():
    xcconfig = (Path(__file__).resolve().parents[2] / "Configuration.xcconfig").read_text()
    values = {
        key.strip(): value.strip()
        for key, value in (
            line.split("=", 1) for line in xcconfig.splitlines() if "=" in line and not line.lstrip().startswith("//")
        )
    }
    marketing = values["MARKETING_VERSION"]
    build = values["CURRENT_PROJECT_VERSION"]
    major, minor, patch = (int(p) for p in marketing.split("."))
    # The xcconfig's build must be what the generator derives for some
    # amphetamine suffix of the same marketing version.
    base = int(generate_appcast.build_number(major, minor, patch, 0))
    assert 0 < int(build) - base < 100
