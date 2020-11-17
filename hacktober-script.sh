#! /bin/bash
set -o pipefail

## argument parsing
function printHelp() {
echo 'this tool builds a report of users with more than N PRs in some public GitHub repositories. This is usefull if you are running a Hacktoberfest challange.'
echo '--org : if specified, will get the list of repositories for this organization.  this flag will override --repo.'
echo '--repo : if specified, will include PRs from this repo. must be in the form of "organization/repo". this flag can be specified multiple times. this flag will be overriden by --org'
echo '--since : only take PRs since this ISO 8601 date'
echo '--before : only take PRs before this ISO 8601 date'
echo '--labels : only take PRs with all of these labels defined (comma seperated)'
echo '--minpr : find users with at least this many PRs'
echo '--noclean : specify this boolean flag (no value requires) to keep the intermediate artifacts generated by the scripts'
echo '--token : if specified, will use the token as a bearer token to authenticate with GitHub. Authenticating increases throttling limits. Can be a GitHub personal access token or a JWT token'
echo '--workdir : if specified, will skip downloading from GitHub API, and will generate the report against an existing directory that was previously populated with data by running this tool and the --noclean flag.'
echo 'example: hacktober-script.sh --repo aquasecurity/kube-hunter --repo aquasecurity/trivy --since "2019-10-01T00:00:00Z" --before "2019-10-31T00:00:00Z" --minpr 3'
echo 'example: hacktober-script.sh --org aquasecurity --since "2019-10-01T00:00:00Z" --before "2019-10-31T00:00:00Z" --minpr 3 --noclean --token a1b2c3'
echo 'example: hacktober-script.sh --workdir "/path/to/dir" --since "2019-10-01T00:00:00Z" --before "2019-10-31T00:00:00Z" --minpr 3 --noclean'
echo 'requirements: bash 4+, jq, gnu find (gfind on mac), gnu sed (gsed on mac), curl, tee'
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --org)
        org="$2"
        shift
        shift
        ;;
        --repo)
        repos+=("$2")
        shift
        shift
        ;;
        --since)
        since="$2"
        shift
        shift
        ;;
        --before)
        before="$2"
        shift
        shift
        ;;
        --labels)
        labels="$2"
        shift
        shift
        ;;
        --minpr)
        minpr="$2"
        shift
        shift
        ;;
        --noclean)
        noclean=true
        shift
        ;;
        --token)
        token="$2"
        shift
        shift
        ;;
        --workdir)
        workdir="$2"
        shift
        shift
        ;;
        -h|--help)
        printHelp
        shift
        shift
        ;;
        *)
        shift
        ;;
    esac
done
[[ -z $since || -z $before || -z $minpr || ( -z $repos && -z $org && -z $workdir ) ]] && printHelp && exit 1

# use gnu utiils on mac
find="find"
command -v gfind 1>/dev/null && find="gfind"
sed="sed"
command -v gsed 1>/dev/null && sed="gsed"

if [ -z "$workdir" ]; then 
    workdir=$(mktemp -d)
    echo "workdir is $workdir"

    function getGhApiWithPagination() {
        local nexturl=$1
        local outdir=$2
        # we construct the auth variable as an array to allow proper expension into words
        [ -n "$token" ] && local auth=('-H' "Authorization: token $token")

        i=0
        while [ -n "$nexturl" ]; do
            echo "getting $nexturl"
            nexturl=$(curl "${auth[@]}" -sv --fail --create-dirs "$nexturl" -o "$outdir/$i.json" 2>&1 | "$sed" -rn 's/^< Link:.*<(.*?)>; rel="next",.*/\1/p')
            # note that the following check requires pipefail setting
            [ "$?" -ne 0 ] && echo "API call failed! expect partial results if any. this may be related to throttling"
            ((i++))
        done
    }

    ## generate repo list
    if [[ -n $org ]]; then
        getGhApiWithPagination "https://api.github.com/orgs/$org/repos" "$workdir/repos"
        jq --slurp --raw-output '. | flatten | .[].full_name' \
            $("$find" "$workdir/repos" -type f -printf "%p ")>"$workdir/repolist"
        repos=($(cat $workdir/repolist))
    fi

    ## download issues
    for repo in "${repos[@]}"; do
        # PRs in Github are issues. There's a `pulls` endpoint as well but issues has the info we need.
        # issues which are PRs have a `pull_request` field in the issue object, so we will filter for that on client.
        # since is a filter on the update time of an issue (not the created), so we'll need to further filter on client.
        # maximal page size is 100
        getGhApiWithPagination "https://api.github.com/repos/$repo/issues?filter=all&state=all&labels=$labels&since=$since&per_page=100" "$workdir/data/${repo/\//_}"
    done
fi

## build report
# here we pass the relevant argument to jq as arguments. the minpr is passed as json so it will be parsed as a number instead of string.
jq --slurp --arg since "$since" --arg before "$before" --argjson minpr "$minpr" \
    '. | flatten |
    [
        .[] |
        select(.created_at >= $since and .created_at <= $before) |
        select(. | has("pull_request")) |
        select((.labels | length == 0) or (.labels | .[].name != "invalid")) |
        {"author":.user.login, "created": .created_at}
    ] |
    group_by(.author) |
    map(select(. | length >= $minpr))' \
    $("$find" $workdir/data -type f -printf "%p ")> "$workdir/res.json"

## output aggregated results
jq '. | map({"author":.[0].author, "prs":. | length})' "$workdir/res.json" | tee "$workdir/agg.json"

## cleanup
if [[ ! $noclean ]]; then
    echo "removing workdir $workdir"
    rm -rf "$workdir"
else
    echo "data is kept in workdir $workdir"
fi
