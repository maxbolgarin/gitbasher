#!/usr/bin/env bash

### Script for managing git tags
# Read README.md to get more information how to use it
# Semver reference: https://semver.org/
# Use this script only with gitbasher


### Function pushes tag and prints url to repo or error
# $1: tag to push, empty for pushing all tags
# $2: delete flag, pass it if you want to delete provided tag
# Using of global:
#     * origin_name
function push_tag {
    if [ -z "$1" ] || [ "$1" == "" ]; then
        all="true"
        push_output=$(git push $origin_name --tags 2>&1)
    elif [ -n "$2" ]; then
        push_output=$(git push --delete $origin_name $1 2>&1)
    else
        push_output=$(git push $origin_name $1 2>&1)
    fi
    push_code=$?

    # Handle delete case
    if [ -n "$delete" ]; then
        if [[ "$push_output" == *"remote ref does not exist"* ]]; then
            echo -e "${RED}Tag '$1' doesn't exist in '${origin_name}'${ENDCOLOR}"
            exit
        fi
        echo -e "${GREEN}Successful deleted tag '$1' in '${origin_name}'!${ENDCOLOR}"
        exit
    fi
    
    repo=$(get_repo)

    # Print `push-all` result
    if [ -n "$all" ]; then
        echo

        IFS=$'\n' read -rd '' -a lines_with_success <<< "$(sed -n '/\[new tag\]/p' <<< "$push_output")"

        number_of_tags=${#lines_with_success[@]}
        if [ $number_of_tags != 0 ]; then
            echo -e "${GREEN}Pushed successfully${ENDCOLOR}"
            
            for index in "${!lines_with_success[@]}"
            do
                echo -e "\t$(sed -e 's#.*\-> \(\)#\1#' <<< "${lines_with_success[index]}" )"
            done
            echo
        fi
    fi

    # Handle errors
    if [ $push_code != 0 ] ; then
        if [[ "$push_output" == *"Updates were rejected because the tag already exists in the remote"* ]]; then
            echo -e "${RED}Some tags were rejected${ENDCOLOR}"

            IFS=$'\n' read -rd '' -a lines_with_rejected <<< "$(sed -n '/\[rejected\]/p' <<< "$push_output")"
            for index in "${!lines_with_rejected[@]}"
            do
                echo -e "\t$(sed -e 's#.*\-> \(\)#\1#' <<< "${lines_with_rejected[index]}" )"
            done

            echo
            echo -e "${YELLOW}Repo:${ENDCOLOR} ${repo}"
            exit
        fi
        
        echo -e "${RED}Cannot push! Here is the error${ENDCOLOR}"
        echo "$push_output"
        exit $push_code
    fi

    # Print result
    if [[ $push_output == *"Everything up-to-date"* ]]; then
        echo -e "${GREEN}Everything up-to-date${ENDCOLOR}"
    elif [ -z "$all" ]; then
        echo -e "${GREEN}Successful push tag '$1'!${ENDCOLOR}"
    else
        echo -e "${GREEN}Successful push all local tags!${ENDCOLOR}"
    fi

    echo -e "${YELLOW}Repo:${ENDCOLOR}\t${repo}"

    if [ -z "$all" ]; then
        if [[ $repo == *"github"* ]]; then
            echo -e "${YELLOW}Tag:${ENDCOLOR}\t${repo}/releases/tag/$1"
        elif [[ $repo == *"gitlab"* ]]; then
            echo -e "${YELLOW}Tag:${ENDCOLOR}\t${repo}/-/tags/$1"
        fi
    fi
}


### Main function
# $1: mode
    # <empty>: create a new tag from a current branch and commit
    # commit: select commit instead of using current one (or select tag when pushing or deleting)
    # annotated: create an annotated tag with message
    # full: create an annotated tag with message and select commit instead of using current one
    # list: print list of local tags and exit
    # remote: fetch tags from the remote and print the list
    # push: select tag to push
    # push-all: push all tags
    # delete: select tag to delete
    # delete: delete all tags
function tag_script {
    case "$1" in
        commit|c|co|cm) 
            select="true"
            commit="true"
        ;;
        annotated|a|an) annotated="true";;
        full|f) 
            select="true"
            annotated="true"
            full="true"
        ;;
        list|log|l) list="true";;
        remote|r|re)
            list="true"
            remote="true"
        ;;
        push|ps|ph|p)
            push="true"
            select="true"
            push_single="true"
        ;;
        push-all|pa) push="true";;
        delete|del|d) 
            delete="true"
            select="true"
            delete_single="true"
        ;;
        delete-all|da) delete="true";;
        help|h) help="true";;

        *)
            wrong_mode "tag" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb tag <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tCreate a new tag from a current commit and push it to a remote"
        echo -e "commit|c|co|cm\tCreate a new tag from a selected commit and push it to a remote"
        echo -e "annotated|a|an\tCreate a new annotated tag from a current commit and push it to a remote"
        echo -e "full|f\tCreate a new annotated tag from a selected commit and push it to a remote"
        echo -e "list|log|l\tPrint a list of local tags"
        echo -e "remote|r|re\tFetch tags from a remote and print it"
        echo -e "push|ps|ph|p\tSelect a local tag for pushing to a remote"
        echo -e "push-all|pa\tPush all tags to a remote"
        echo -e "delete|del|d\tSelect a tag to delete in local and remote"
        echo -e "delete-all|da\tDelete all local tags"
        echo -e "help|h\t\tShow this help"
        exit
    fi


    ### Print header
    header="GIT TAG"
    if [ -n "${commit}" ]; then
        header="$header COMMIT"
    elif [ -n "${full}" ]; then
        header="$header FULL"
    elif [ -n "${annotated}" ]; then
        header="$header ANNOTATED"
    elif [ -n "${list}" ]; then
        header="$header LIST"
    elif [ -n "${remote}" ]; then
        header="$header REMOTE"
    elif [ -n "${push_single}" ]; then
        header="$header PUSH"
    elif [ -n "${push}" ]; then
        header="$header PUSH ALL"
    elif [ -n "${delete_single}" ]; then
        header="$header DELETE"
    elif [ -n "${delete}" ]; then
        header="$header DELETE ALL"    
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    ### Fetch tags from the remote
    if [ -n "${remote}" ]; then
        echo -e "${YELLOW}Fetching all tags from remote...${ENDCOLOR}"
        fetch_output=$(git fetch $origin_name --tags 2>&1)
        fetch_code=$?

        echo
        
        if [ $fetch_code != 0 ]; then
            echo -e "${RED}Cannot fetch tags! Here is the error${ENDCOLOR}"
            echo -e "${fetch_output}"
            exit $fetch_code
        fi

        if [ "$fetch_output" != "" ]; then
            echo -e "${YELLOW}New tags${ENDCOLOR}"
            IFS=$'\n' read -rd '' -a lines_with_tags <<< "$(sed -n '/\[new tag\]/p' <<< "$fetch_output")"
            for index in "${!lines_with_tags[@]}"
            do
                echo -e "\t$(sed -e 's#.*\-> \(\)#\1#' <<< "${lines_with_tags[index]}" )"
            done
            echo
        fi
    fi


    ### Print tag list
    count=14
    if [ -n "${delete}" ] || [ -n "${list}" ]; then
        count=999  # Show all tags
    fi

    tags_info_str=$(git for-each-ref --count=$count --format="%(refname:short) | %(creatordate:relative) | %(objectname:short) - %(contents:subject)" --sort=-creatordate refs/tags | column -ts'|' )
    tags_str=$(git for-each-ref --count=$count --format="%(refname:short)" --sort=-creatordate refs/tags)
    commit_hashes_str=$(git for-each-ref --count=$count --format="%(objectname:short)" --sort=-creatordate refs/tags)

    IFS=$'\n' read -rd '' -a tags_info <<<"$tags_info_str"
    IFS=$'\n' read -rd '' -a tags <<<"$tags_str"
    IFS=$'\n' read -rd '' -a commit_hashes <<<"$commit_hashes_str"

    number_of_tags=${#tags[@]}

    if [ $number_of_tags == 0 ]; then
        echo -e "${YELLOW}There is no local tags${ENDCOLOR}"
        if [ -n "${delete}" ]; then
            exit
        fi
    else
        tags_header="Last ${number_of_tags} local tags"
        if [ -n "${delete}" ] || [ -n "${list}" ]; then
            tags_header="All ${number_of_tags} local tags"
        fi
        echo -e "${YELLOW}${tags_header}${ENDCOLOR}"

        for index in "${!tags[@]}"
        do
            tag=$(escape "${tags[index]}" "/")
            tag_line=$(sed "1,/${tag}/ s/${tag}/${GREEN_ES}${tag}${ENDCOLOR_ES}/" <<< ${tags_info[index]})
            tag_line=$(sed "1,/${commit_hashes[index]}/ s/${commit_hashes[index]}/${YELLOW_ES}${commit_hashes[index]}${ENDCOLOR_ES}/" <<< "$tag_line")
            if [ -n "${delete}" ] || [ -n "${push}" ]; then
                echo -e "$(($index+1)). ${tag_line}"
            else
                echo -e "${tag_line}"
            fi
        done
    fi

    if [ -n "$list" ]; then
        exit
    fi


    ### Push all case
    if [ -n "$push" ] && [ -z "$select" ]; then
        echo
        echo -e "${YELLOW}Pushing all tags..."${ENDCOLOR}

        push_tag
        exit
    fi


    ### Delete all case
    if [ -n "${delete}" ] && [ -z "$select" ]; then
        echo
        echo -e "${YELLOW}Do you really want to delete all local tags (y/n)?${ENDCOLOR}"
        yes_no_choice "Deleting..."
        git tag | xargs git tag -d 
        exit
    fi


    ### Select tag for delete / push
    if [ -n "${delete}" ] || [ -n "$push" ]; then
        echo "0. Exit..."
        echo
        if [ -n "${delete}" ]; then
            printf "Enter tag number to delete: "
        else
            printf "Enter tag number to push: "
        fi

        choose "${tags[@]}"
        tag_name=$choice_result

        if [ $number_of_tags -gt 9 ] && [ $choice -gt 9 ]; then
            echo  # User press enter if choice < 10
        fi
        echo

        # Push case
        if [ -n "${push}" ]; then
            echo -e "${YELLOW}Pushing..."${ENDCOLOR}
            echo
            push_tag $tag_name
            exit
        fi

        delete_result=$(git tag -d $tag_name 2>&1)
        delete_code=$?

        if [ $delete_code != 0 ]; then
            echo -e "${RED}Cannot delete tag '${tag_name}'!${ENDCOLOR}"
            echo -e "$delete_result"
            exit
        fi

        echo -e "${GREEN}Successfully deleted tag '${tag_name}'${ENDCOLOR}"
        echo
        echo -e "Do you want to delete this tag in ${YELLOW}${origin_name}${ENDCOLOR} (y/n)?"
        yes_no_choice "Deleting..."
        push_tag $tag_name "true"

        exit
    fi
    echo


    ### Select commit for new tag
    if [ -n "$select" ]; then
        echo -e "${YELLOW}Select commit for a new tag on branch '$current_branch'${ENDCOLOR}"
        choose_commit 9

        echo 
        echo -e "${YELLOW}Selected commit${ENDCOLOR}"


    ### Use current commit for new tag
    else
        commit_hash=$(git rev-parse HEAD)
        echo -e "${YELLOW}Current commit${ENDCOLOR}"
    fi

    commit_message=$(git log -1 --pretty=%B $commit_hash | cat)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR} ${commit_message}"


    ### Enter name for a new tag
    echo
    echo -e "${YELLOW}Enter the name of a new tag${ENDCOLOR}"
    echo -e "If this tag will be using for release, use version number in semver format like '1.0.0-alpha'"
    echo -e "Leave it blank to exit"

    if [ -n "${annotated}" ]; then
        prompt="$(echo -n -e "${TODO}git tag -a${ENDCOLOR} ")"
    else
        prompt="$(echo -n -e "${TODO}git tag${ENDCOLOR} ")"
    fi

    read -p "$prompt" -e tag_name

    if [ -z "$tag_name" ]; then
        exit
    fi

    if [[ "$tag_name" == "tag" ]] || [[ "$tag_name" == *" "* ]]; then
        echo
        echo -e "${RED}This name is forbidden!${ENDCOLOR}"
        exit
    fi
    echo


    ### If annotated - enter tag message
    if [ -n "$annotated" ]; then
        tag_file=".tagmsg__"
        touch $tag_file

        echo """
###
### Write some words about a new tag '${tag_name}'
### [$current_branch ${commit_hash::7}] ${commit_message}
### 
### You can place changelog here, if this tag means a new release
""" >> $tag_file

        while [ true ]; do
            $editor $tag_file
            tag_message=$(cat $tag_file | sed '/^#/d')

            if [ -n "$tag_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}Tag message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                find . -name "$tag_file*" -delete
                exit
            fi    
        done

        find . -name "$tag_file*" -delete
    fi


    if [ -z "$select" ]; then
        commit_hash=""
    fi


    ### Finally create tag
    if [ -n "$annotated" ]; then
        tag_output=$(git tag -a -m """$tag_message""" $tag_name $commit_hash 2>&1)
    else
        tag_output=$(git tag $tag_name $commit_hash 2>&1)
    fi

    tag_code=$?

    if [ $tag_code != 0 ]; then
        if [[ $tag_output == *"already exists" ]]; then
            echo -e "${RED}Tag '${tag_name}' already exists!${ENDCOLOR}"
        else
            echo -e "${RED}Cannot create tag '${tag_name}'!${ENDCOLOR}"
            echo -e "$tag_output"
        fi
        exit
    fi

    if [ -n "$annotated" ]; then
        is_annotated=" annotated"
    fi

    if [ -n "$select" ]; then
        is_commit_hash=" from commit '${commit_hash}'"
    fi

    echo -e "${GREEN}Successfully created${is_annotated} tag '${tag_name}'${is_commit_hash}!${ENDCOLOR}"

    if [ -n "$tag_message" ]; then
        echo -e "$tag_message"
    fi
    echo


    ### Push tag
    echo -e "Do you want to push this tag to ${YELLOW}${origin_name}${ENDCOLOR} (y/n)?"
    yes_no_choice "Pushing..."

    push_tag $tag_name
}