* Support warmup_script option,  which runs after smoke test to enhance smoothness of DNS switching in Blue Green deployment.
* Wait for all auto scaling group to reach MIN size before running smoke tests in Blue Green deployment. This will make sure DNS switching not generating 50x error under big load, even without warmup steps.
* Refactoring: extract Config class wrapping config defaut and merging logic.
* Make clear solution_stack is a creation only option in document
* Updating an EB environment with a different solution_stack should give warning
* Remove all old environment settings to keep settings always sync up
* Make it possible to provide an environment specific components settings
* Support smoke_test_script option
* Document for how to use components
* Document for how to use inactive-settings
* Support bucket folders for different environments (e.g. tworker/dev,tworker/ci)
