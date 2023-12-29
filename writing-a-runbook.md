---
description: Automating day to day processes with RealmJoin.
---

# How to write a Powershell Runbook for RealmJoin with the RealmJoin.RunbookHelper Module #

This guide will provide a basic rundown of how to successfully create a PowerShell Runbook with the help of the RealmJoin.RunbookHelper Module and how to deploy it in Azure Active Directory for use within the RealmJoin Portal 

{% hint style="warning" %}
Disclaimer: This guide heavily references existing documentation about RealmJoin which can be found [here](https://docs.realmjoin.com/).
{% endhint %}


> Disclaimer: This guide heavily references existing documentation about RealmJoin which can be found [here](https://docs.realmjoin.com/).


## Getting started ##
Currently our Runbooks are stored in a [GitHub repository](https://github.com/realmjoin/realmjoin-runbooks), which is public and can be accessed from anywhere.

Since we use git as our version control tool, a great first step is [downloading and installing git](https://git-scm.com/downloads), unless you already have it. If you're a beginner and need a quick overview on how to use git, this [cheatsheet](https://training.github.com/downloads/github-git-cheat-sheet/) might come in handy.
After configuring git you're ready to start and clone the repository on your machine so you can be able to contribute with your own Runbooks.

A good IDE in which you can develop your Runbooks is [Visual Studio Code](https://code.visualstudio.com/), which can be downloaded [here](https://code.visualstudio.com/Download). [First Steps with VS Code](https://code.visualstudio.com/docs)

Once you've opened your code editor of choice navigate(via your Terminal) to a directory where the code will be stored locally. There you can execute the following git command:
```
$ git clone https://github.com/realmjoin/realmjoin-runbooks
```
This will clone(download) the code from the repository to your machine, where you can immediately start developing. 

## Runbook Structure ## 
Lets take a closer look at how a Runbook is built. The structure is always the same for every Runbook:
rename-device.ps1
```

```