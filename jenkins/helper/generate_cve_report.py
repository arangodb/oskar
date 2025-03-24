import json
import os
from jinja2 import Environment, FileSystemLoader
from datetime import datetime
import sys

if len(sys.argv) != 3:
    print("This script generates an HTML report from the JSON files output by the Grype scanner. Files must be named grypeResult*.json.\nUsage: python generate_cve_report.py [path to directory containing JSON files] [name of the HTML report file]")
    sys.exit(1)

results_path = sys.argv[1]
report_filename = sys.argv[2]

json_results = []
filenames = [f for f in os.listdir(results_path) if f.startswith("grypeResult") and f.endswith(".json")]
if len(filenames) == 0:
    print("No grypeResult*.json files found in the specified directory.")
    sys.exit(1)
for filename in filenames:
    file_path = os.path.join(results_path, filename)
    if os.path.isfile(file_path):
        with open(file_path, "r") as file:
            json_results.append(json.load(file))

report_data = {}
report_data["scan_date"] = json_results[0]["descriptor"]["timestamp"]
report_data["grype_version"] = json_results[0]["descriptor"]["version"]
report_data["db_date"] = json_results[0]["descriptor"]["db"]["built"]
report_data["scans"] = []

severity_order = {
    "Critical": 0,
    "High": 1,
    "Medium": 2,
    "Low": 3,
    "Negligible": 4,
    "Unknown": 5,
}

for result in json_results:
    table_entry = {}
    table_entry["image_tags"] = "<br>".join(result["source"]["target"]["tags"])
    table_entry["vulnerabilities"] = []
    for match in result["matches"]:
        vulnerability = match["vulnerability"]
        artifact = match.get("artifact", {})
        vulnerability_entry = {}
        vulnerability_entry["id"] = vulnerability.get("id", "")
        vulnerability_entry["dataSource"] = vulnerability.get("dataSource", "")
        vulnerability_entry["description"] = vulnerability.get("description", "")
        vulnerability_entry["severity"] = vulnerability.get("severity", "")
        vulnerability_entry["artifact_name"] = artifact.get("name", "")
        vulnerability_entry["artifact_type"] = artifact.get("type", "")
        vulnerability_entry["artifact_version"] = artifact.get("version", "")
        vulnerability_entry["fixed_versions"] = "<br>".join(
            vulnerability.get("fix", {}).get("versions", [])
        )
        table_entry["vulnerabilities"].append(vulnerability_entry)
    table_entry["vulnerabilities"] = sorted(
        table_entry["vulnerabilities"],
        key=lambda x: severity_order.get(x["severity"], 5),
    )
    table_entry["row_count_total"] = len(table_entry["vulnerabilities"])
    table_entry["row_count_high_critical"] = len(
        [
            v
            for v in table_entry["vulnerabilities"]
            if v["severity"] in ["Critical", "High"]
        ]
    )
    report_data["scans"].append(table_entry)

env = Environment(loader=FileSystemLoader("."))
template = env.get_template("template.html")
html_output = template.render(report_data)

with open(report_filename, "w", encoding="utf-8") as file:
    file.write(html_output)
