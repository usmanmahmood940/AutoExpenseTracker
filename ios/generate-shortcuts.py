#!/usr/bin/env python3
"""
Generate importable iOS Shortcut files for Auto Expense Tracker.
Run: python3 ios/generate-shortcuts.py
Output: ios/export/*.shortcut (signed, ready to AirDrop to iPhone)
"""

from __future__ import annotations

import plistlib
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXPORT = ROOT / "export"
UNSIGNED = EXPORT / "_unsigned"
SIGNED = EXPORT

WEBHOOK_URL = (
    "https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransaction"
)
API_KEY_PLACEHOLDER = "PASTE_YOUR_WEBHOOK_API_KEY_HERE"
BANK_NAME_PLACEHOLDER = "PASTE_YOUR_BANK_NAME_HERE"


def uid() -> str:
    return str(uuid.uuid4()).upper()


def tt(s: str, att: dict | None = None) -> dict:
    value: dict = {"string": s}
    if att:
        value["attachmentsByRange"] = att
    return {"Value": value, "WFSerializationType": "WFTextTokenString"}


def oref(action_uuid: str, output_name: str) -> dict:
    return {
        "Value": {
            "OutputUUID": action_uuid,
            "Type": "ActionOutput",
            "OutputName": output_name,
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def var_ref(name: str) -> dict:
    return {"Value": {"Type": "Variable", "VariableName": name}, "WFSerializationType": "WFTextTokenAttachment"}


def dv(items: list[dict]) -> dict:
    return {
        "Value": {"WFDictionaryFieldValueItems": items},
        "WFSerializationType": "WFDictionaryFieldValue",
    }


def di_key_value(key: str, value_ref: dict) -> dict:
    return {"WFKey": tt(key), "WFItemType": 0, "WFValue": value_ref}


def di_static(key: str, value: str) -> dict:
    return {"WFKey": tt(key), "WFItemType": 0, "WFValue": tt(value)}


def base_workflow(actions: list[dict], *, accepts_text_input: bool = True) -> dict:
    workflow: dict = {
        "WFWorkflowClientRelease": "2302.0.4",
        "WFWorkflowClientVersion": "2302.0.4",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": 4282601983,
            "WFWorkflowIconGlyphNumber": 59511,
        },
        "WFWorkflowTypes": ["NCWidget", "WatchKit"],
        "WFWorkflowActions": actions,
    }
    if accepts_text_input:
        workflow["WFWorkflowInputContentItemClasses"] = ["WFStringContentItem"]
        workflow["WFWorkflowHasShortcutInputVariables"] = True
    return workflow


def action(identifier: str, params: dict) -> dict:
    if "UUID" not in params:
        params = {**params, "UUID": uid()}
    return {
        "WFWorkflowActionIdentifier": identifier,
        "WFWorkflowActionParameters": params,
    }


def shortcut_input_var() -> dict:
    return {"Type": "Variable", "VariableName": "Shortcut Input"}


def prepend_otp_guard(actions: list[dict]) -> list[dict]:
    """Skip OTP messages — no webhook, no pending queue."""
    blocks: list[dict] = []
    for token in ("OTP", "otp"):
        group = uid()
        blocks.extend(
            [
                action(
                    "is.workflow.actions.conditional",
                    {
                        "WFControlFlowMode": 0,
                        "GroupingIdentifier": group,
                        "WFCondition": 8,
                        "WFConditionalActionString": token,
                        "WFInput": shortcut_input_var(),
                    },
                ),
                action(
                    "is.workflow.actions.showresult",
                    {"Text": "Skipped: OTP message (not logged)"},
                ),
                action("is.workflow.actions.exit", {}),
                action(
                    "is.workflow.actions.conditional",
                    {
                        "WFControlFlowMode": 2,
                        "GroupingIdentifier": group,
                    },
                ),
            ]
        )
    return blocks + actions


def build_send_to_webhook() -> dict:
    api_uuid = uid()
    bank_uuid = uid()
    url_uuid = uid()
    idem_uuid = uid()
    date_uuid = uid()
    http_uuid = uid()

    actions = prepend_otp_guard(
        [
        action(
            "is.workflow.actions.gettext",
            {
                "UUID": api_uuid,
                "CustomOutputName": "API Key",
                "WFTextActionText": API_KEY_PLACEHOLDER,
            },
        ),
        action(
            "is.workflow.actions.gettext",
            {
                "UUID": bank_uuid,
                "CustomOutputName": "Bank Name",
                "WFTextActionText": BANK_NAME_PLACEHOLDER,
            },
        ),
        action(
            "is.workflow.actions.gettext",
            {
                "UUID": url_uuid,
                "CustomOutputName": "Webhook URL",
                "WFTextActionText": WEBHOOK_URL,
            },
        ),
        action(
            "is.workflow.actions.gethtmlfromrichtext",
            {
                "UUID": idem_uuid,
                "CustomOutputName": "Idempotency Key",
                "WFHTMLActionType": "UUID",
            },
        ),
        action(
            "is.workflow.actions.format.date",
            {
                "UUID": date_uuid,
                "CustomOutputName": "Received At",
                "WFDateActionMode": "Relative",
                "WFDateActionFormat": "ISO 8601",
                "WFISO8601IncludeTime": True,
            },
        ),
        action(
            "is.workflow.actions.downloadurl",
            {
                "UUID": http_uuid,
                "CustomOutputName": "Webhook Response",
                "WFURL": oref(url_uuid, "Webhook URL"),
                "WFHTTPMethod": "POST",
                "ShowHeaders": True,
                "WFHTTPHeaders": dv(
                    [
                        di_static("Content-Type", "application/json"),
                        di_key_value("X-API-Key", oref(api_uuid, "API Key")),
                    ]
                ),
                "WFHTTPBodyType": "JSON",
                "WFJSONValues": dv(
                    [
                        di_key_value("raw", var_ref("Shortcut Input")),
                        di_static("source", "ios_shortcut"),
                        di_key_value("bank", oref(bank_uuid, "Bank Name")),
                        di_key_value("receivedAt", oref(date_uuid, "Received At")),
                        di_key_value("idempotencyKey", oref(idem_uuid, "Idempotency Key")),
                    ]
                ),
            },
        ),
        action(
            "is.workflow.actions.detect.text",
            {
                "CustomOutputName": "Response Dictionary",
                "WFInput": oref(http_uuid, "Webhook Response"),
                "WFTextDetectionType": "Dictionary",
            },
        ),
        action(
            "is.workflow.actions.output",
            {
                "WFOutput": oref(http_uuid, "Response Dictionary"),
            },
        ),
        ]
    )

    workflow = base_workflow(actions)
    workflow["WFWorkflowImportQuestions"] = [
        {
            "ActionIndex": 0,
            "Category": "Parameter",
            "ParameterKey": "WFTextActionText",
            "Text": "Enter your WEBHOOK_API_KEY (same value you set in Firebase)",
            "DefaultValue": "",
        },
        {
            "ActionIndex": 1,
            "Category": "Parameter",
            "ParameterKey": "WFTextActionText",
            "Text": "Enter your bank name (e.g. HBL, UBL, Meezan) — sent with every message",
            "DefaultValue": "HBL",
        },
    ]
    return workflow


def build_manual_test() -> dict:
    ask_uuid = uid()
    run_uuid = uid()
    success_uuid = uid()
    txn_uuid = uid()
    err_uuid = uid()
    msg_uuid = uid()

    actions = [
        action(
            "is.workflow.actions.ask",
            {
                "UUID": ask_uuid,
                "CustomOutputName": "Bank Message",
                "WFAskActionPrompt": "Paste bank SMS or email text:",
                "WFInputType": "Text",
            },
        ),
        action(
            "is.workflow.actions.runworkflow",
            {
                "UUID": run_uuid,
                "CustomOutputName": "Webhook Result",
                "WFWorkflow": {"workflowName": "Expense - Send to Webhook"},
                "WFInput": oref(ask_uuid, "Bank Message"),
            },
        ),
        action(
            "is.workflow.actions.detect.text",
            {
                "CustomOutputName": "Result Dictionary",
                "WFInput": oref(run_uuid, "Webhook Result"),
                "WFTextDetectionType": "Dictionary",
            },
        ),
        action(
            "is.workflow.actions.getvalueforkey",
            {
                "UUID": success_uuid,
                "CustomOutputName": "Success",
                "WFDictionaryKey": "success",
                "WFInput": oref(run_uuid, "Result Dictionary"),
            },
        ),
        action(
            "is.workflow.actions.getvalueforkey",
            {
                "UUID": txn_uuid,
                "CustomOutputName": "Transaction ID",
                "WFDictionaryKey": "transactionId",
                "WFInput": oref(run_uuid, "Result Dictionary"),
            },
        ),
        action(
            "is.workflow.actions.getvalueforkey",
            {
                "UUID": err_uuid,
                "CustomOutputName": "Error",
                "WFDictionaryKey": "error",
                "WFInput": oref(run_uuid, "Result Dictionary"),
            },
        ),
        action(
            "is.workflow.actions.gettext",
            {
                "UUID": msg_uuid,
                "CustomOutputName": "Status Message",
                "WFTextActionText": {
                    "Value": {
                        "string": "Success: \ufffc\nTransaction: \ufffc\nError: \ufffc",
                        "attachmentsByRange": {
                            "{10, 1}": {
                                "Type": "ActionOutput",
                                "OutputUUID": success_uuid,
                                "OutputName": "Success",
                            },
                            "{24, 1}": {
                                "Type": "ActionOutput",
                                "OutputUUID": txn_uuid,
                                "OutputName": "Transaction ID",
                            },
                            "{32, 1}": {
                                "Type": "ActionOutput",
                                "OutputUUID": err_uuid,
                                "OutputName": "Error",
                            },
                        },
                    },
                    "WFSerializationType": "WFTextTokenString",
                },
            },
        ),
        action(
            "is.workflow.actions.alert",
            {
                "WFAlertActionTitle": "Expense Log Result",
                "WFAlertActionMessage": oref(msg_uuid, "Status Message"),
            },
        ),
        action(
            "is.workflow.actions.showresult",
            {
                "Text": oref(msg_uuid, "Status Message"),
            },
        ),
    ]

    return base_workflow(actions, accepts_text_input=False)


def build_drain_pending_info() -> dict:
    """Shortcut that explains drain setup — Numbers automation is device-specific."""
    actions = [
        action(
            "is.workflow.actions.gettext",
            {
                "WFTextActionText": (
                    "Drain Pending requires the Numbers sheet setup.\n\n"
                    "1. Import 'Expense - Send to Webhook' first\n"
                    "2. Create Numbers sheet 'Expense Pending Queue'\n"
                    "3. Follow ios/shortcuts/03-drain-pending.md to finish\n\n"
                    "Or run 'Expense - Manual Test Log' to test the webhook now."
                ),
            },
        ),
        action(
            "is.workflow.actions.showresult",
            {
                "Text": {
                    "Type": "Variable",
                    "Variable": {"Type": "ActionOutput", "OutputName": "Text"},
                },
            },
        ),
    ]
    return base_workflow(actions, accepts_text_input=False)


def write_and_sign(name: str, workflow: dict) -> Path:
    UNSIGNED.mkdir(parents=True, exist_ok=True)
    SIGNED.mkdir(parents=True, exist_ok=True)

    unsigned_path = UNSIGNED / f"{name}.shortcut"
    signed_path = SIGNED / f"{name}.shortcut"

    with unsigned_path.open("wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)

    subprocess.run(
        [
            "shortcuts",
            "sign",
            "-i",
            str(unsigned_path),
            "-o",
            str(signed_path),
            "--mode",
            "anyone",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return signed_path


def main() -> None:
    shortcuts = [
        ("Expense - Send to Webhook", build_send_to_webhook()),
        ("Expense - Manual Test Log", build_manual_test()),
        ("Expense - Drain Pending (setup)", build_drain_pending_info()),
    ]

    print("Generating signed iOS Shortcuts...\n")
    for name, workflow in shortcuts:
        path = write_and_sign(name, workflow)
        print(f"  ✓ {path.relative_to(ROOT.parent)}")

    print(
        "\nImport on iPhone:\n"
        "  1. AirDrop the .shortcut files from ios/export/ to your iPhone\n"
        "  2. Tap each file → Add Shortcut\n"
        "  3. On 'Send to Webhook' import, paste WEBHOOK_API_KEY and bank name when prompted\n"
        "  4. Run 'Manual Test Log' to verify\n"
    )


if __name__ == "__main__":
    main()
