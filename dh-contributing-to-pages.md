---
title: Contributing to DataHub documentation
layout: page
---

# Working on DataHub documentation

DataHub documentation uses content from FAIRDOM-SEEK documentation.

## FAIRDOM-SEEK documentation

FAIRDOM-SEEK documentation is in branches of the GitHub repository seek4science/seek
* gh-pages
* gh-pages-1.13
* gh-pages-master
* gh-pages-sample-update: temporary branch to record features agreed upon during sample working group

## DataHub documentation

FAIRDOM-SEEK documentation (gh-pages branches) has been cloned in GitHub
* [ELIXIR-Belgium/DataHub-help](https://github.com/ELIXIR-Belgium/DataHub-help): to deploy documentation of the [DataHub production instance](https://datahub.elixir-belgium.org).
* [ELIXIR-Belgium/DataHub-help-test](https://github.com/ELIXIR-Belgium/DataHub-help-test): to deploy [documentation](https://help.datahub-test.elixir-belgium.org) of the [DataHub test instance](https://datahub-test.elixir-belgium.org). Forked from ELIXIR-Belgium/DataHub-help.
* [ELIXIR-Belgium/DataHub-help-usecase](https://github.com/ELIXIR-Belgium/DataHub-help-usecase): to deploy [documentation](https://help.datahub-usecase.elixir-belgium.org) of the [DataHub usecase instance](https://datahub-usecase.elixir-belgium.org). Forked from ELIXIR-Belgium/DataHub-help.

## How to contribute to DataHub documentation

### General way of working
1. Create [issues on ELIXIR-Belgium/DataHub-help](https://github.com/ELIXIR-Belgium/DataHub-help/issues).
2. Use [ELIXIR-Belgium/DataHub-help-test](https://github.com/ELIXIR-Belgium/DataHub-help-test) to propose changes to the DataHub documentation pages via pull requests.
3. DataHub team will review and approve/reject your changes.
4. DataHub team will push the changes towards ELIXIR-Belgium/DataHub-help.

### via GitHub GUI
1. Go to [ELIXIR-Belgium/DataHub-help-test](https://github.com/ELIXIR-Belgium/DataHub-help-test).
2. Make the changes you want to propose.
3. Open a pull request from your fork (e.g. `username:patch-N`, that is created by GitHub by default) towards [ELIXIR-Belgium/DataHub-help-test](https://github.com/ELIXIR-Belgium/DataHub-help-test) - `main` branch. You can click the "*compare across forks*" button to check which repository-branch you are making your pull request to:
  * "head repository": it must be your fork; "compare": it must be your branch
  * "base repository": it must be `ELIXIR-Belgium/DataHub-help-test`; "base": it must be `main`

IMPORTANT: please make sure that your pull request is towards the base repository ELIXIR-Belgium/DataHub-help-**test** and the `main` branch, and not towards DataHub-help.

4. Follow up via GitHub for comments from the DataHub team.

### via code editor of your choice (e.g. VSCode)

This is a general workflow in how to work on your own fork (copy) of the repository and request changes through a pull request.
1. In GitHub, make a fork of [ELIXIR-Belgium/DataHub-help-test](https://github.com/ELIXIR-Belgium/DataHub-help-test) using the fork button. Then go to `Code --> SSH --> copy`
2. Open a terminal and choose a directory. Then type
    ```
    git clone git@github.com:ELIXIR-Belgium/DataHub-help-test.git
    cd DataHub-help-test
    ```
3. Set your fork of DataHub-Help (e.g. username/DataHub-help) as your **remote**
4. By default ELIXIR-Belgium/DataHub-help-test is your **origin**
5. When making changes
* Keep your fork up to date by pulling from **origin** (ELIXIR-Belgium/DataHub-help-test).
* Create a new branch named after your feature/edit and make the changes you want to make.
* Commit and push to **remote** (e.g. username/DataHub-help).
6. In GitHub, open a pull request and make sure to set ELIXIR-Belgium/DataHub-help-test main as base repository.

IMPORTANT: please check that your pull request is against DataHub-help-**test** main and not DataHub-help.
