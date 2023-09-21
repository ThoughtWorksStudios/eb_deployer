0.7.0
=====

* Add service specific AWS sdk gems
* [#79](https://github.com/ThoughtWorksStudios/eb_deployer/pull/79): Environment updates can complete with errors
* [#82](https://github.com/ThoughtWorksStudios/eb_deployer/pull/82): Added a line to force STDOUT output every line
* [#85](https://github.com/ThoughtWorksStudios/eb_deployer/pull/85): Improve package not found error message
* [#86](https://github.com/ThoughtWorksStudios/eb_deployer/pull/86): Fix to for inactive stack updates when instances are 0
 
0.6.6
=====

* Add support for specifying (and overriding) a [stack policy](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/protect-stack-resources.html) for the CloudFormation resource stack. (contributed by @jlabrecque)
* Fix issue where deployment hangs if resource stack update fails and stack is rolled back, deployment will now fail when the resource stack update fails. (contributed by @jlabrecque)
* Add support for creating environment base on a elasticbeanstalk template. (contributed by @djpate)

0.6.5
=====

* #66: Making it possible to specify other accepted health states when deploying (@dziemid)

0.6.4
=====

* fixes #65 - aws driver should be able to detect CNAME prefixes from both regionalized and legacy EB domains

0.6.3
=====

* Wait until inactive environment status is ready before applying settings.

0.6.0
=====

* Use aws-sdk 2.0
* Ruby 2.2 support
* Robust error handling on CloudFormation resource stack provisioning

0.5.1
=====

* Fix issue: worker tier is picking up old version of aws-sqsd

0.5.0
=====

* Worker tier support

0.4.12
======

* Update default solution stacks.
* Rails generator generates SECRET_KEY_BASE for rails 4 app.

0.4.11
======

* Make gem depend on aws-sdk-v1 until we put in support for both v1 and v2

0.4.10
======

* Fix #33

0.4.9
====

* Ignore AWS::ElasticBeanstalk::Errors::OperationInProgressFailure error when delete application version

0.4.8
====
* Raise an error if the environment launched with problems (contributed by kmanning)
* Add --stack-name option that let's use choose the name of the cloud
  formation stack to operate on (contributed by NET-A-PORTER)
* Document typo/grammar fix (contributed by stig)
* Retry on AWS API throttling error when operating on versions

0.4.7
====
* Added blue-only deployment strategy (a variant of blue-green) that
  skips the cname swap so that the newly deployed code remains on the
  inactive "blue" instance. (contributed by jlabrecque)

0.4.6
====
* Make elasticbeanstalk event polling robust against clock shifting problem.

0.4.5
====
* Rails 3+ support: Rails Generator to install default configurations with
	Postgres RDS resource and everything need for blue-green
	deployment
* Add ability to tag beanstalk environment (from @pmcfadden)

0.4.4
=====
* Fix S3 upload on Windows.
* Experimental support for "inactve_settings" options, which can be used to automatically scale down the inactive environment.
* Update default solution stack name to latest supported JAVA stack.
* Validate solution_stack option before creating environment and list available solution_stacks if not valid.

0.4.3
=====
* Backoff and retry when AWS::ElasticBeanstalk::Errors::Throttling happens during polling events

0.4.2
=====
* Allow provding different deploy strategy for different components.

0.4.1
=====
* Remove options for delete all environments ("-d --all"), because it is too destructive and not recoverable.
* Experimental support for multiple components deployment.

0.4.0
====
* revert back all changes from 0.3.8 to 0.3.9. Elasticbeanstalk haven't relex the real unique constain. The actually contrain is you can not have environment name cross different application

0.3.9
====
* Fix hang problem introduced in 0.3.8 when migrating old ElasticBeanstalk environment.
* Fix issue #13 (Deployment via S3 object broken since 0.3.7)

0.3.8
=====
* Change ElasticBeanstalk environment name pattern. Stop using sufix hash to make eb environment global unique. (Because ElasticBeanstalk does not require environment has globally uniqe name any more.)
* Add migration logic so that if a ElasticBeanstalk environment with legcy name exists, eb_deployer will automaticly terminate it and replace it with ElasticBeanstalk environment has new name pattern.
