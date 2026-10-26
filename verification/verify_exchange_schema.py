#!/usr/bin/env python3
"""
Epanalipsi kai Epalithefsi tou R0lling Exchange Schema v1.
Basismeno sto docs/contracts/r0lling-exchange-v1.schema.json.
Elegxei aystira:
- oneOf validation (journalFile i backupManifest)
- ISO-8601 UTC whole seconds timestamp format (oxi fractional seconds)
- Uppercase UUID hex pattern (oxi lowercase)
- MediaType kai MediaRelativePath prefixes (Photos/, Videos/, Clips/, Audio/)
- Ypoxreotika pedia gia journalEntry, mediaAttachment, agentMemory, backupManifest
- Negative regression tests gia entopismo akyron payloads
"""

from __future__ import annotations

import sys
import os
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Windows console encoding fix
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

ROOT_DIR = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT_DIR / "docs" / "contracts" / "r0lling-exchange-v1.schema.json"

REGEX_TIMESTAMP = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
REGEX_UUID = re.compile(r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")
REGEX_MEDIA_PATH = re.compile(r"^(Photos|Videos|Clips|Audio)/[0-9A-Za-z_-][0-9A-Za-z._-]{0,254}$")
REGEX_OBSIDIAN_HASH_KEY = re.compile(r"^[0-9]{4}/[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$")
REGEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")

EGYRA_ENTRY_SOURCES = {"manual", "glasses", "glasses_clip", "voice", "import", "ai"}
EGYRA_MEDIA_TYPES = {"photo", "video", "clip", "audio"}


class ElegxosExchangeSchema:
    """Aystiros elegktis sumforfosis me to r0lling-exchange-v1.schema.json."""

    def __init__(self, schema_dict: Dict[str, Any]) -> None:
        self.schema = schema_dict
        self.defs = schema_dict.get("$defs", {})

    def elegxos_timestamp(self, timi: Any, path: str = "") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(timi, str):
            sfalmata.append(f"{path}: To timestamp prepei na einai string, brethike {type(timi).__name__}")
        elif not REGEX_TIMESTAMP.match(timi):
            sfalmata.append(f"{path}: To timestamp '{timi}' den tairiazei sto ISO-8601 UTC whole seconds format")
        return sfalmata

    def elegxos_uuid(self, timi: Any, path: str = "") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(timi, str):
            sfalmata.append(f"{path}: To UUID prepei na einai string, brethike {type(timi).__name__}")
        elif not REGEX_UUID.match(timi):
            sfalmata.append(f"{path}: To UUID '{timi}' den einai uppercase hex canonical UUID")
        return sfalmata

    def elegxos_media_attachment(self, attachment: Dict[str, Any], path: str = "") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(attachment, dict):
            return [f"{path}: To mediaAttachment prepei na einai object"]

        ypoxreotika = ["id", "relativePath", "mediaType", "byteSize", "captureTimestamp", "hasAudio"]
        for pedio in ypoxreotika:
            if pedio not in attachment:
                sfalmata.append(f"{path}: Leipei to ypoxreotiko pedio '{pedio}'")

        if sfalmata:
            return sfalmata

        sfalmata.extend(self.elegxos_uuid(attachment["id"], f"{path}.id"))
        sfalmata.extend(self.elegxos_timestamp(attachment["captureTimestamp"], f"{path}.captureTimestamp"))

        media_type = attachment["mediaType"]
        if media_type not in EGYRA_MEDIA_TYPES:
            sfalmata.append(f"{path}.mediaType: Akyros typos media '{media_type}'")

        rel_path = attachment["relativePath"]
        if not isinstance(rel_path, str) or not REGEX_MEDIA_PATH.match(rel_path):
            sfalmata.append(f"{path}.relativePath: Akyro path '{rel_path}'")
        else:
            # allOf checks
            if media_type == "photo" and not rel_path.startswith("Photos/"):
                sfalmata.append(f"{path}: photo prepei na ksekina me 'Photos/', brethike '{rel_path}'")
            elif media_type == "video" and not rel_path.startswith("Videos/"):
                sfalmata.append(f"{path}: video prepei na ksekina me 'Videos/', brethike '{rel_path}'")
            elif media_type == "clip" and not rel_path.startswith("Clips/"):
                sfalmata.append(f"{path}: clip prepei na ksekina me 'Clips/', brethike '{rel_path}'")
            elif media_type == "audio" and not rel_path.startswith("Audio/"):
                sfalmata.append(f"{path}: audio prepei na ksekina me 'Audio/', brethike '{rel_path}'")

        if not isinstance(attachment["byteSize"], int) or attachment["byteSize"] < 0:
            sfalmata.append(f"{path}.byteSize: Prepei na einai mi-arnitikos integer")

        if not isinstance(attachment["hasAudio"], bool):
            sfalmata.append(f"{path}.hasAudio: Prepei na einai boolean")

        # additionalProperties false check
        epitrepomena = {"id", "relativePath", "originalFilename", "mediaType", "byteSize", "durationSeconds", "captureTimestamp", "width", "height", "hasAudio"}
        for k in attachment:
            if k not in epitrepomena:
                sfalmata.append(f"{path}: Mi epitrepomeno pedio '{k}'")

        return sfalmata

    def elegxos_journal_entry(self, entry: Dict[str, Any], path: str = "") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(entry, dict):
            return [f"{path}: To journalEntry prepei na einai object"]

        ypoxreotika = ["id", "timestamp", "timeZoneIdentifier", "content", "source", "tags", "attachments", "isFavorite", "lastModified"]
        for pedio in ypoxreotika:
            if pedio not in entry:
                sfalmata.append(f"{path}: Leipei to ypoxreotiko pedio '{pedio}'")

        if sfalmata:
            return sfalmata

        sfalmata.extend(self.elegxos_uuid(entry["id"], f"{path}.id"))
        sfalmata.extend(self.elegxos_timestamp(entry["timestamp"], f"{path}.timestamp"))
        sfalmata.extend(self.elegxos_timestamp(entry["lastModified"], f"{path}.lastModified"))

        if not isinstance(entry["timeZoneIdentifier"], str) or len(entry["timeZoneIdentifier"]) == 0:
            sfalmata.append(f"{path}.timeZoneIdentifier: Prepei na einai mi keno string")

        if not isinstance(entry["content"], str):
            sfalmata.append(f"{path}.content: Prepei na einai string")

        source = entry["source"]
        if source not in EGYRA_ENTRY_SOURCES:
            sfalmata.append(f"{path}.source: Akyri pigi '{source}'")

        if not isinstance(entry["tags"], list) or not all(isinstance(t, str) for t in entry["tags"]):
            sfalmata.append(f"{path}.tags: Prepei na einai array of strings")

        if not isinstance(entry["isFavorite"], bool):
            sfalmata.append(f"{path}.isFavorite: Prepei na einai boolean")

        if not isinstance(entry["attachments"], list):
            sfalmata.append(f"{path}.attachments: Prepei na einai array")
        else:
            for idx, att in enumerate(entry["attachments"]):
                sfalmata.extend(self.elegxos_media_attachment(att, f"{path}.attachments[{idx}]"))

        epitrepomena = {"id", "timestamp", "timeZoneIdentifier", "title", "content", "source", "tags", "locationName", "attachments", "isFavorite", "lastModified"}
        for k in entry:
            if k not in epitrepomena:
                sfalmata.append(f"{path}: Mi epitrepomeno pedio '{k}'")

        return sfalmata

    def elegxos_agent_memory(self, memory: Dict[str, Any], path: str = "") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(memory, dict):
            return [f"{path}: To agentMemory prepei na einai object"]

        ypoxreotika = ["memoryNotes", "userPreferences", "openLoops", "lastUpdated"]
        for pedio in ypoxreotika:
            if pedio not in memory:
                sfalmata.append(f"{path}: Leipei to ypoxreotiko pedio '{pedio}'")

        if sfalmata:
            return sfalmata

        for str_field in ["memoryNotes", "userPreferences", "openLoops"]:
            if not isinstance(memory[str_field], str):
                sfalmata.append(f"{path}.{str_field}: Prepei na einai string")

        sfalmata.extend(self.elegxos_timestamp(memory["lastUpdated"], f"{path}.lastUpdated"))

        epitrepomena = {"memoryNotes", "userPreferences", "openLoops", "lastUpdated"}
        for k in memory:
            if k not in epitrepomena:
                sfalmata.append(f"{path}: Mi epitrepomeno pedio '{k}'")

        return sfalmata

    def elegxos_journal_file(self, doc: Dict[str, Any], path: str = "journalFile") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(doc, dict):
            return [f"{path}: Prepei na einai object"]

        ypoxreotika = ["schemaVersion", "appVersion", "lastUpdated", "entries"]
        for pedio in ypoxreotika:
            if pedio not in doc:
                sfalmata.append(f"{path}: Leipei to ypoxreotiko pedio '{pedio}'")

        if sfalmata:
            return sfalmata

        if doc["schemaVersion"] != 1:
            sfalmata.append(f"{path}.schemaVersion: Prepei na einai akribos 1")

        if not isinstance(doc["appVersion"], str):
            sfalmata.append(f"{path}.appVersion: Prepei na einai string")

        sfalmata.extend(self.elegxos_timestamp(doc["lastUpdated"], f"{path}.lastUpdated"))

        if not isinstance(doc["entries"], list):
            sfalmata.append(f"{path}.entries: Prepei na einai array")
        else:
            for idx, entry in enumerate(doc["entries"]):
                sfalmata.extend(self.elegxos_journal_entry(entry, f"{path}.entries[{idx}]"))

        epitrepomena = {"schemaVersion", "appVersion", "lastUpdated", "entries"}
        for k in doc:
            if k not in epitrepomena:
                sfalmata.append(f"{path}: Mi epitrepomeno pedio '{k}'")

        return sfalmata

    def elegxos_backup_manifest(self, doc: Dict[str, Any], path: str = "backupManifest") -> List[str]:
        sfalmata: List[str] = []
        if not isinstance(doc, dict):
            return [f"{path}: Prepei na einai object"]

        ypoxreotika = ["schemaVersion", "backupTimestamp", "appVersion", "entriesCount", "entries"]
        for pedio in ypoxreotika:
            if pedio not in doc:
                sfalmata.append(f"{path}: Leipei to ypoxreotiko pedio '{pedio}'")

        if sfalmata:
            return sfalmata

        if doc["schemaVersion"] != 1:
            sfalmata.append(f"{path}.schemaVersion: Prepei na einai akribos 1")

        sfalmata.extend(self.elegxos_timestamp(doc["backupTimestamp"], f"{path}.backupTimestamp"))

        if not isinstance(doc["appVersion"], str):
            sfalmata.append(f"{path}.appVersion: Prepei na einai string")

        if not isinstance(doc["entriesCount"], int) or doc["entriesCount"] < 0 or doc["entriesCount"] > 50000:
            sfalmata.append(f"{path}.entriesCount: Prepei na einai integer metaxy 0 kai 50000")

        if not isinstance(doc["entries"], list):
            sfalmata.append(f"{path}.entries: Prepei na einai array")
        elif len(doc["entries"]) > 50000:
            sfalmata.append(f"{path}.entries: Yperbasi tou megistou oriou 50000 entries")
        else:
            for idx, entry in enumerate(doc["entries"]):
                sfalmata.extend(self.elegxos_journal_entry(entry, f"{path}.entries[{idx}]"))
                # maxItems 256 for attachments in backup
                if isinstance(entry, dict) and "attachments" in entry and isinstance(entry["attachments"], list):
                    if len(entry["attachments"]) > 256:
                        sfalmata.append(f"{path}.entries[{idx}].attachments: Yperbasi tou oriou 256 attachments")

        if "agentMemory" in doc and doc["agentMemory"] is not None:
            sfalmata.extend(self.elegxos_agent_memory(doc["agentMemory"], f"{path}.agentMemory"))

        epitrepomena = {"schemaVersion", "backupTimestamp", "appVersion", "entriesCount", "entries", "agentMemory"}
        for k in doc:
            if k not in epitrepomena:
                sfalmata.append(f"{path}: Mi epitrepomeno pedio '{k}'")

        return sfalmata

    def elegxos_document(self, doc: Dict[str, Any]) -> Tuple[bool, List[str]]:
        # oneOf: journalFile OR backupManifest
        sfalmata_journal = self.elegxos_journal_file(doc)
        sfalmata_backup = self.elegxos_backup_manifest(doc)

        if not sfalmata_journal:
            return True, []
        if not sfalmata_backup:
            return True, []

        return False, [f"To document den tairiazei oute ws journalFile: {sfalmata_journal} oute ws backupManifest: {sfalmata_backup}"]


def ektelesi_dokimon() -> int:
    print("=== R0lling Exchange Schema v1 Smoke & Parity Test ===")
    if not SCHEMA_PATH.exists():
        print(f"[ERR] FAIL: To schema arxeio den brethike sto {SCHEMA_PATH}")
        return 1

    try:
        with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
            schema_data = json.load(f)
        print(f"[OK] PASS: Fortosi Schema epituxis ('{schema_data.get('title')}')")
    except Exception as e:
        print(f"[ERR] FAIL: Sfalma fortosis schema: {e}")
        return 1

    elegktis = ElegxosExchangeSchema(schema_data)

    # 1. Dokimi Egkyrou Journal File
    egkyro_journal = {
        "schemaVersion": 1,
        "appVersion": "1.0.0",
        "lastUpdated": "2026-10-26T10:00:00Z",
        "entries": [
            {
                "id": "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D",
                "timestamp": "2026-10-26T09:30:00Z",
                "timeZoneIdentifier": "Europe/Athens",
                "title": "Dokimi Prwines Simeiwseis",
                "content": "Katagrafi protou entry gia epalithefsi schema.",
                "source": "manual",
                "tags": ["personal", "journal"],
                "attachments": [
                    {
                        "id": "B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E",
                        "relativePath": "Photos/morning_view.jpg",
                        "originalFilename": "morning_view.jpg",
                        "mediaType": "photo",
                        "byteSize": 2048500,
                        "captureTimestamp": "2026-10-26T09:28:00Z",
                        "hasAudio": False
                    }
                ],
                "isFavorite": True,
                "lastModified": "2026-10-26T09:30:00Z"
            }
        ]
    }

    epituxia, sfalmata = elegktis.elegxos_document(egkyro_journal)
    if epituxia:
        print("[OK] PASS: Egkyro Journal File epalitheftike me apolyti akriveia")
    else:
        print(f"[ERR] FAIL: To egkyro Journal File apetuxe: {sfalmata}")
        return 1

    # 2. Dokimi Egkyrou Backup Manifest
    egkyro_backup = {
        "schemaVersion": 1,
        "backupTimestamp": "2026-10-26T10:15:00Z",
        "appVersion": "1.0.0",
        "entriesCount": 1,
        "entries": egkyro_journal["entries"],
        "agentMemory": {
            "memoryNotes": "O xristis protima dark theme kai local-first sync.",
            "userPreferences": "locale: el_GR, tz: Europe/Athens",
            "openLoops": "Spike 1 Windows Narrator verification",
            "lastUpdated": "2026-10-26T10:15:00Z"
        }
    }

    epituxia, sfalmata = elegktis.elegxos_document(egkyro_backup)
    if epituxia:
        print("[OK] PASS: Egkyro Backup Manifest epalitheftike me apolyti akriveia")
    else:
        print(f"[ERR] FAIL: To egkyro Backup Manifest apetuxe: {sfalmata}")
        return 1

    # 3. Negative Regression Tests (Aporripsi akyron payloads)
    print("--- Negative Regression Tests (Zero-Trust Validation) ---")

    # 3.1 Lowercase UUID rejection
    akyro_uuid = json.loads(json.dumps(egkyro_journal))
    akyro_uuid["entries"][0]["id"] = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d"  # lowercase
    ep, sf = elegktis.elegxos_document(akyro_uuid)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to lowercase UUID")
    else:
        print("[ERR] FAIL: To lowercase UUID egine lanthasmena apodekto!")
        return 1

    # 3.2 Fractional seconds timestamp rejection
    akyro_tz = json.loads(json.dumps(egkyro_journal))
    akyro_tz["entries"][0]["timestamp"] = "2026-10-26T09:30:00.123Z"  # fractional seconds
    ep, sf = elegktis.elegxos_document(akyro_tz)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to fractional-seconds timestamp (.123Z)")
    else:
        print("[ERR] FAIL: To fractional-seconds timestamp egine lanthasmena apodekto!")
        return 1

    # 3.3 Media folder mismatch rejection (photo in Videos/)
    akyro_folder = json.loads(json.dumps(egkyro_journal))
    akyro_folder["entries"][0]["attachments"][0]["relativePath"] = "Videos/morning_view.jpg"
    ep, sf = elegktis.elegxos_document(akyro_folder)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to mediaType/folder mismatch (photo in Videos/)")
    else:
        print("[ERR] FAIL: To mediaType/folder mismatch egine lanthasmena apodekto!")
        return 1

    # 3.4 Missing captureTimestamp rejection
    akyro_no_capture = json.loads(json.dumps(egkyro_journal))
    del akyro_no_capture["entries"][0]["attachments"][0]["captureTimestamp"]
    ep, sf = elegktis.elegxos_document(akyro_no_capture)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to mediaAttachment xoris captureTimestamp")
    else:
        print("[ERR] FAIL: To attachment xoris captureTimestamp egine lanthasmena apodekto!")
        return 1

    # 3.5 Path traversal attempt rejection (Photos/../Photos/evil.jpg)
    akyro_traversal = json.loads(json.dumps(egkyro_journal))
    akyro_traversal["entries"][0]["attachments"][0]["relativePath"] = "Photos/../Photos/evil.jpg"
    ep, sf = elegktis.elegxos_document(akyro_traversal)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to path traversal attempt (../)")
    else:
        print("[ERR] FAIL: To path traversal egine lanthasmena apodekto!")
        return 1

    # 3.6 Hidden file attempt rejection (Photos/.hidden.jpg)
    akyro_hidden = json.loads(json.dumps(egkyro_journal))
    akyro_hidden["entries"][0]["attachments"][0]["relativePath"] = "Photos/.hidden.jpg"
    ep, sf = elegktis.elegxos_document(akyro_hidden)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to hidden file attempt (Photos/.)")
    else:
        print("[ERR] FAIL: To hidden file attempt egine lanthasmena apodekto!")
        return 1

    # 3.7 Space in relative path rejection (Photos/my file.jpg)
    akyro_space = json.loads(json.dumps(egkyro_journal))
    akyro_space["entries"][0]["attachments"][0]["relativePath"] = "Photos/my file.jpg"
    ep, sf = elegktis.elegxos_document(akyro_space)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to keno sto relativePath")
    else:
        print("[ERR] FAIL: To relativePath me keno egine lanthasmena apodekto!")
        return 1

    # 3.8 Non-Z Timezone Offset rejection (+02:00)
    akyro_offset = json.loads(json.dumps(egkyro_journal))
    akyro_offset["entries"][0]["timestamp"] = "2026-10-26T09:30:00+02:00"
    ep, sf = elegktis.elegxos_document(akyro_offset)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to non-Z timezone offset (+02:00)")
    else:
        print("[ERR] FAIL: To non-Z timezone offset egine lanthasmena apodekto!")
        return 1

    # 3.9 Non-hex character 'G' in UUID rejection
    akyro_hex = json.loads(json.dumps(egkyro_journal))
    akyro_hex["entries"][0]["id"] = "G1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D"
    ep, sf = elegktis.elegxos_document(akyro_hex)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to non-hex char sto UUID ('G')")
    else:
        print("[ERR] FAIL: To UUID me 'G' egine lanthasmena apodekto!")
        return 1

    # 3.10 Schema Version Mismatch rejection (schemaVersion: 2)
    akyro_version = json.loads(json.dumps(egkyro_journal))
    akyro_version["schemaVersion"] = 2
    ep, sf = elegktis.elegxos_document(akyro_version)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to akyro schemaVersion (2)")
    else:
        print("[ERR] FAIL: To schemaVersion 2 egine lanthasmena apodekto!")
        return 1

    # 3.11 Negative byteSize rejection (byteSize: -50)
    akyro_bytes = json.loads(json.dumps(egkyro_journal))
    akyro_bytes["entries"][0]["attachments"][0]["byteSize"] = -50
    ep, sf = elegktis.elegxos_document(akyro_bytes)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to arnitiko byteSize (-50)")
    else:
        print("[ERR] FAIL: To arnitiko byteSize egine lanthasmena apodekto!")
        return 1

    # 3.12 Exceeded entriesCount boundary in backup manifest (entriesCount: 50001)
    akyro_count = json.loads(json.dumps(egkyro_backup))
    akyro_count["entriesCount"] = 50001
    ep, sf = elegktis.elegxos_document(akyro_count)
    if not ep:
        print("[OK] PASS: Aporrifthike epituxws to entriesCount boundary violation (50001)")
    else:
        print("[ERR] FAIL: To entriesCount 50001 egine lanthasmena apodekto!")
        return 1

    print("ALL EXCHANGE SCHEMA TESTS (12/12 EDGE CASES) PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(ektelesi_dokimon())
