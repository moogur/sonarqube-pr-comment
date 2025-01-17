#!/usr/bin/env bash

projectInfoUrl="${SONAR_HOST_URL}/api/measures/component?component=${SONAR_PROJECT_KEY}&metricKeys=bugs,vulnerabilities,security_hotspots,security_hotspots_reviewed,code_smells,coverage,lines_to_cover,quality_gate_details,duplicated_lines_density,lines&branch=${GIT_BRANCH}"
project_info="$(curl --silent --fail --show-error --user "${SONAR_TOKEN}": "${projectInfoUrl}")"

readarray -t arrayMetrics < <(jq -c '.component.measures[]' <<< "$project_info")
title=
table_head="|*Metric*|*Value*|"
table_separator="|:-|:-:|"
table_body=

for metricObj in "${arrayMetrics[@]}"; do
  metric=$(jq -c '.metric' <<< "$metricObj")
  value=$(jq -c '.value' <<< "$metricObj")

  if [[ "$metric" == "\"quality_gate_details\"" ]]; then
    prepared_value=$(echo "$value" | tr "\"" " " | awk '{ print $4 }') # value is 'OK' or 'ERROR'

    if [[ $prepared_value == "OK\\" ]]; then
      prefix="✅"
    else
      prefix="💣"
    fi

      title="$prefix Status: **${prepared_value%?}**"
  else
    prepared_metric=$(echo "${metric^}" | tr "_" " ")
    table_body+="|${prepared_metric:1:-1}|${value:1:-1}"
    if [[ "$metric" == "\"security_hotspots_reviewed\"" ]] || [[ "$metric" == "\"duplicated_lines_density\"" ]] || [[ "$metric" == "\"coverage\"" ]]; then
      table_body+=" %"
    fi
    table_body+="|\n"
  fi

done

result="$title\n\n$table_head\n$table_separator\n$table_body"
echo "quality_check<<EOF" >> $GITHUB_OUTPUT

if [[ ${#arrayMetrics[@]} == 0 ]]; then
  echo "UNKNOWN ERROR" >> "$GITHUB_OUTPUT"
  echo "Message - $project_info" >> "$GITHUB_OUTPUT"
else
  echo "$result" >> "$GITHUB_OUTPUT"
fi

echo "EOF" >> "$GITHUB_OUTPUT"
