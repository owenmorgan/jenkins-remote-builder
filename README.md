#Build Jenkins Jobs Remotely

##Example

    jenkins=https://user:pass@jenkins.mydomain.com:8080
    jenkins_job=MyApp-Deploy

    environment=dev
    application=myapp
    revision=9fd71f63b351b8208264daf86d292ced580a2f60

    ./jenkins_remote_trigger.sh \
                -h ${jenkins} \
                -j ${jenkins_job} \
                -p "ENVIRONMENT=${environment}&APPLICATION=${application}&REVISION=${revision}"


##Usage:

    -h HOST     | --host=HOST                       Jenkins host
    -j JOBNAME  | --jobname=test-build-job          The name of the jenkins job to trigger
    -p JOBPARAM | --jobparam=environment=uat&test=1 Jenkins job paramiters
    -q          | --quiet                           Don't output any status messages


##TODO:

* Timeout