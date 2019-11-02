# filter our specific authors
jq '[.[] | select(.author != "itaysk" and .author != "someuser")]' ./res.json > filtered.json

# count total prs across all authors
jq 'reduce .[].prs as $authprs (0; . + $authprs)' filtered.json 

# count authors with at least 3 prs
jq '[.[] |  select(.prs >= 3)] | reduce .[].prs as $authprs (0; . + $authprs)' filtered.json