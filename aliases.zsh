# @author     Sebastian Tramp <mail@sebastian.tramp.name>
# @license    http://opensource.org/licenses/gpl-license.php
#
# alias definitions which can be edited/modified with 'aedit'
#

export EDITOR="vim"
# But still use emacs-style zsh bindings
# http://superuser.com/questions/403355/how-do-i-get-searching-through-my-command-history-working-with-tmux-and-zshell
bindkey -e

alias vi="vim"
alias ctags='/usr/local/bin/ctags'

##### standard aliases (start with a space to be ignored in history)
# default ls is untouched, except coloring
alias ls=' ls --color=auto'
alias myls=' ls -C -F -h --color=always'
alias l=" myls -l"
alias ll=' myls -l'
alias la=' myls -lA'


alias cd=' cd'
alias ..=' cd ..; ls'
alias ...=' cd ..; cd ..; ls'
alias ....=' cd ..; cd ..; cd ..; ls'
alias cd..='..'
alias cd...='...'
alias cd....='....'

# rails process
alias master='ps -ef | grep master'
alias sidekiq='ps -ef | grep sidekiq'

#git
alias grm='git rm'
alias gadd='git add'
alias gdiff='git diff'
alias gpull='git pull'
alias gpush='git push origin master'
alias gstatus='git status'
alias gcommit='git commit -m'
alias gpushdev='git push origin develop'
alias gpulldev='git pull origin develop'
alias gcheckout='git checkout'

#directory
alias workspace='cd /Users/luolin/workspace;ll'

alias cloudhorn='cd /Users/luolin/workspace/cloudhorn;ll'
alias mobileapi='cd /Users/luolin/workspace/cloudhorn/shenbian_mobile_api_ruby;ll'
alias vimmobileapi='cd /Users/luolin/workspace/cloudhorn/shenbian_mobile_api_ruby;vim .'
alias sublmobileapi='cd /Users/luolin/workspace/cloudhorn/shenbian_mobile_api_ruby;subl .'

alias backend='cd /Users/luolin/workspace/cloudhorn/shenbian_backend;ll'
alias vimbackend='cd /Users/luolin/workspace/cloudhorn/shenbian_backend;vim .'

alias hesheng='cd /Users/luolin/workspace/hesheng;ll'

alias read='cd /Users/luolin/workspace/hesheng/hs_read;ll'
alias sublread='cd /Users/luolin/workspace/hesheng/hs_read;subl .'
alias science='cd /Users/luolin/workspace/hesheng/science_read;ll'
alias vimscience='cd /Users/luolin/workspace/hesheng/science_read;vim .'
alias health_record='cd /Users/luolin/workspace/hesheng/health_records;ll'
alias sublrecord='cd /Users/luolin/workspace/hesheng/health_records;subl .'
alias galaxy='cd /Users/luolin/workspace/hesheng/galaxy;ll'
alias subgalaxy='cd /Users/luolin/workspace/hesheng/galaxy;subl .'

#ssh
alias sshBlog=". ~/servers/blog"

alias sshHeshengMQ=". ~/servers/rabbitmq"
alias sshHeshengGit=". ~/servers/git"
alias sshHeshengTest=". ~/servers/test"
alias sshHeshengRead=". ~/servers/read"
alias sshHeshengScience=". ~/servers/science"
alias sshHeshengWebsite=". ~/servers/website"
alias sshHeshengWaibao=". ~/servers/waibao"
alias sshHeshengXinyao=". ~/servers/xinyao"
#和生视界图像存储内部机器
alias sshHeshengImages=". ~/servers/hesheng_images"

#和生机房业务机器
alias sshXinyao=". ~/servers/xinyao"
alias sshFenji=". ~/servers/fenji"

#眼科医院机器
alias sshHospitalWebsite=". ~/servers/hospital_website"
alias sshZydMeeting=". ~/servers/zyd_meeting"

#云喇叭机器
alias sshShenbianBackend=". ~/servers/shenbian_backend"
alias sshShenbianDev=". ~/servers/shenbian_dev"
alias sshShenbianTest=". ~/servers/shenbian_test"
alias sshShenbianMessageCenter=". ~/servers/shenbian_message_center"
alias sshShenbianState2=". ~/servers/shenbian_state2"
alias sshShenbianMobileApiF16D=". ~/servers/shenbian_mobile_api"
alias sshShenbianMobileapi1=". ~/servers/shenbian_mobileapi1"
alias sshShenbianMobileapi2=". ~/servers/shenbian_mobileapi2"
alias sshShenbianMobileapiYinji=". ~/servers/shenbian_mobileapi_yinji"
alias sshShenbianCRedis=". ~/servers/shenbian_shenbian_credis"

alias deployApi1='mobileapi;bundle exec rake deploy:"to_remote[mobileapi1]" env=prd'
alias deployApi2='mobileapi;bundle exec rake deploy:"to_remote[mobileapi2]" env=prd'
alias deployF16D='mobileapi;bundle exec rake deploy:"to_remote[f16d]" env=prd'
alias deployApi1Api2F16D='mobileapi;bundle exec rake deploy:"to_remote[mobileapi1 mobileapi2 f16d]" env=prd'

alias sshJike=". ~/servers/jike"

#短信飞毛腿
alias sshSmsRabbitMQ=". ~/servers/sms_rabbitmq"
#关机
alias reboot='sudo shutdown -r now'
alias shutdown='sudo shutdown -h now'
