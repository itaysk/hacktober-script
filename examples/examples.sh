# filter out specific authors
jq '[.[] | select(.author != "itaysk" and .author != "someuser")]' ./agg.json > filtered.json

# export list to csv
jq -r '.[] | [.author, .prs] | @csv' filtered.json > list.csv

# count total prs across all authors
jq 'reduce .[].prs as $authprs (0; . + $authprs)' filtered.json 

# count authors with at least 3 prs
jq '[.[] | select(.prs >= 3)] | length' filtered.json

# count prs from authors with at least 3 prs
jq '[.[] |  select(.prs >= 3)] | reduce .[].prs as $authprs (0; . + $authprs)' filtered.json

# delete empty files
find ./data -type f  -size 5c -delete
