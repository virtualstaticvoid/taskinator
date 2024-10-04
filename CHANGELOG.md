v?.?.? - ?? ??? ????
---

v0.6.0 - ?? ??? 2024
---

* Add `before_started`, `after_completed` and `after_failed` functionality.
* Add `logger` helper method, available within task methods.
* Use `SecureRandom.hex(10)` instead of `uuid` for shorter process and tasks IDs.
* Bug fix for options on `sequential`, `concurrent`, `for_each` and `sub_process` methods.
* Bug fix instrumentation payload.
* Documentation updates.

v0.5.2 - 04 Oct 2024
---
* Time arguments fix for Redis 5.0. Fixes #28

v0.5.1 - 06 Jan 2023
---
* Include process definition in processes, tasks and payloads to aid debugging.
* Increased test coverage for process and task specs.
* Removed `statsd` instrumentation.
* Removed unused `Taskinator::Visitor::XmlVisitor` implementation.
* Various refactorings and clean ups.
* Bug fixes for process class when used as a sub-process
* Add handling for unknown types when deserializing old processes
* Raises `UnknownTypeError` when trying to invoke processes or Jobs of unknown types

v0.5.0 - 18 Feb 2022
---
* Removed unused `ProcessWorker` class and related queue methods.
* Refactored `TestQueueAdapter` to correctly implement queue adapter for use in specs.
* Added deprecation for `Taskinator::Process::Concurrent#concurrency_method` option.

v0.4.7 - 17 Feb 2022
---
* Use newer format for `pipelined` and `multi` requests in Redis.

v0.4.6 - 12 Feb 2022
---
* Upgrade actionpack for [information vulnerability fix](https://github.com/virtualstaticvoid/taskinator/security/dependabot/3).

v0.4.5 - 30 Jan 2022
---
* Upgrade sidekiq dependency for [CVE-2022-23837](https://github.com/advisories/GHSA-jrfj-98qg-qjgv).

v0.4.4 - 17 Jan 2022
---
* Add support for `ActiveJob`.

v0.4.3 - 14 Jan 2022
---
* Add `#find_process` and `#find_task` methods to `Taskinator::Api`.
* Bug fix to API when enumerating processes.
* Updated dependencies.

v0.4.2 - 16 Mar 2021
---
* Bug fix for process/task keys not expired upon completion.

v0.4.1 - 15 Mar 2021
---
* Optimisation to exclude sub-processes which don't have any tasks.
* Preparations for upgrade to Ruby 3 and ActiveSupport 6

v0.4.0 - 4 Mar 2021
---
* Bug fix `job` tasks which have no arguments to the `perform` method.
* Added support for having `perform` method as a class method.

v0.3.16 - 17 Feb 2021
---
* Bug fix to decrement pending counts for sequential tasks.
* Bug fix to allow concurrent tasks to be retried (via Resque) and to complete processes.

v0.3.15 - 22 Nov 2018
---
* Updated dependencies.

v0.3.14 - 13 Jul 2018
---
* Updated dependencies.
* Removed gemnasium.

v0.3.13 - 23 Sep 2017
---
* Updated dependencies.

v0.3.12 - 23 Sep 2017
---
* Spec fixes.
* Updated dependencies.

v0.3.11 - 1 Nov 2016
---
* Removed `redis-semaphore` gem and use INCRBY to track pending concurrent tasks instead.
* Added instrumentation using statsd.
* Bug fixes to key expiry logic.
* Refactored process and task state transistions.

v0.3.10 - 1 Nov 2016
---
* Added support for serializing to XML.
* Improvements to process and task states.

v0.3.9 - 12 Sep 2016
---
* Added benchmark for redis-mutex.

v0.3.7 - 18 Aug 2016
---
* Bug fix to `option?` method.

v0.3.6 - 11 Nov 2015
---
* Added visitor for performing clean up of completed processes/tasks.
* Performance improvement to instrumentation payload; removed references to task/process and use intrinsic types.
* Clean up of keys, via `cleanup` method use key expiry.

v0.3.5 - 02 Nov 2015
---
* Updated the keys used when persisting processes and tasks in Redis, so they fall in the same key space.
* Added clean up code to remove data from Redis when a process completes.
* Introduced `Taskinator.generate_uuid` method
* Use Redis pipelined mode to persist processes and tasks.
* Added warning output to log if serialized arguments are bigger than 2MB.
* Introduced scoping for keys in Redis in order to better support multi-tenancy requirements.
* Added XmlVisitor for extracting processes/tasks into XML.
* Introduced `ProcessWorker` (incomplete) which will be used to incrementally build sub-process in order to speed up overall processing for big processes.

v0.3.3 - 29 Oct 2015
---
* Bug fix for options handling when defining processes using `define_concurrent_process`.

v0.3.2 - 18 Sep 2015
---
* Bug fix to argument handling when using `create_process_remotely` method.

v0.3.1 - 16 Sep 2015
---
* Added redis-semaphore gem, for fix to concurrent processes completion logic.

v0.3.0 - 28 Aug 2015
---
* Added created_at and updated_at to process and task as attributes.
* Improved serialization visitor to include an optional converter block for deserialization of attribute values.
* Corrections to lazy loader logic and speed improvements.
* Removed JobWorker as it's no longer necessary.
* Improvements to instrumentation.
* Removed workflow gem, and refactored process and task to implement the basics instead.
* Several bug fixes.

v0.2.0 - 31 Jul 2015
---
* Bug fix for `create_process_remotely` so that it returns the process uuid instead of nil.
* Removed reload functionality, since it isn't used anymore
* Added missing instrumentation events for task, job and subprocess completed events.
* Bug fix for when `sequential` or `concurrent` steps don't have any tasks to still continue processing.
* Refactoring to remove dead code and "reload" functionality.
* Improvements to console and rake to use console instrumenter.
* Consolidation of instrumentation events. Added `type` to payload.
* Improvements to error handling.

v0.1.1 - 23 Jul 2015  [Yanked]
---
* Bug fix for option parameter handling.

v0.1.0 - 23 Jul 2015 [Yanked]
---
* Fixed issue with persistence of options passed to `create_process` on the respective `Process` and `Task` instances.
* Improvements to process creation logic.
* Namespaced instrumentation event names.
* Added process completed, cancelled and failed instrumentation events.
* Include additional data in the instrumentation payload. E.g. Process options and percentages.
* Refactored the way processes/tasks get queued, to prevent unnecessary queuing of contained processes/tasks.
* Removed `ProcessWorker` since it isn't needed anymore.

v0.0.18 - 14 Jul 2015
---
* Fixed issue with `Taskinator::Api::Processes#each` method, which was causing a Segmentation fault.
* Added statistics information.
* Improved specifications code coverage.

v0.0.17 - 11 Jul 2015
---
* Fixed issue with `Taskinator::Task#each` method, which was causing a Segmentation fault.
* Added `define_sequential_process` and `define_concurrent_process` methods for defining processes.
* Added `ConsoleInstrumenter` instrumenter implementation.
* Required `resque` for console and rake tasks, to make debugging easier

v0.0.16 - 25 Jun 2015
---
* Added ability to enqueue the creation of processes; added a new worker, `CreateProcessWorker`
* Added support for instrumentation
* Improvements to error handling
* Bug fix for the persistence of the `queue` attribute for `Process` and `Task`
* Code clean up and additional specs added

v0.0.15 - 28 May 2015
---
* Added ability to specify the queue to use when enqueing processes, tasks and jobs
* Improvements to specs for testing with sidekiq; added `rspec-sidekiq` as development dependency
* Gem dependencies updated as per Gemnasium advisory

v0.0.14 - 12 May 2015
---
* Bug fix for fail! methods
* Bug fix to parameter handling by for_each method

v0.0.13 - 11 May 2015
---
* Bug fix to `Taskinator::Api` for listing of processes; should only include top-level processes
* Gem dependencies updated as per Gemnasium advisory

v0.0.12 - 20 Apr 2015
---
* Gem dependencies updated as per Gemnasium advisory

v0.0.11 - 2 Mar 2015
---
* Gem dependencies updated as per Gemnasium advisory

v0.0.10 - 26 Feb 2015
---
* Documentation updates

v0.0.9 - 19 Dec 2014
---
* Various bug fixes
* Added error logging
* Workflow states now include `complete` event
* Gem dependencies updated as per Gemnasium advisory

v0.0.8 - 11 Nov 2014
---
* Added support for argument chaining with `for_each` and `transform`
* Documentation updates
* Gem dependencies updated as per Gemnasium advisory

v0.0.7 - 16 Oct 2014
---
* Added better option handling; introduced `option?(key)` method
* Added support for definining the expected arguments for a process
* Gem dependencies updated as per Gemnasium advisory

v0.0.5 - 17 Sep 2014
---
* Various of bug fixes
* Improved error handling
* Added logging for queuing of processes, tasks and jobs

v0.0.4 - 12 Sep 2014
---
* Improvements to serialization; make use of GlobalID functionality
* Added support for "job" tasks; reusing existing workers as tasks

v0.0.3 - 2 Sep 2014
---
* Added failure steps to workflow of processes and tasks

v0.0.2 - 12 Aug 2014
---
* Refactored how tasks are defined in definitions

v0.0.1 - 12 Aug 2014
---
* Initial release
