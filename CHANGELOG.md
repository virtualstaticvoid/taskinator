v0.0.15 - 28 May 2015
---
Added ability to specify the queue to use when enqueing processes, tasks and jobs
Improvements to specs for testing with sidekiq; added `rspec-sidekiq` as development dependency
Gem dependencies updated as per Gemnasium advisory

v0.0.14 - 12 May 2015
---
Bug fix for fail! methods
Bug fix to parameter handling by for_each method

v0.0.13 - 11 May 2015
---
Bug fix to `Taskinator::Api` for listing of processes; should only include top-level processes
Gem dependencies updated as per Gemnasium advisory

v0.0.12 - 20 Apr 2015
---
Gem dependencies updated as per Gemnasium advisory

v0.0.11 - 2 Mar 2015
---
Gem dependencies updated as per Gemnasium advisory

v0.0.10 - 26 Feb 2015
---
Documentation updates

v0.0.9 - 19 Dec 2014
---
Various bug fixes
Added error logging
Workflow states now include `complete` event
Gem dependencies updated as per Gemnasium advisory

v0.0.8 - 11 Nov 2014
---
Added support for argument chaining with `for_each` and `transform`
Documentation updates
Gem dependencies updated as per Gemnasium advisory

v0.0.7 - 16 Oct 2014
---
Added better option handling; introduced `option?(key)` method
Added support for definining the expected arguments for a process
Gem dependencies updated as per Gemnasium advisory

v0.0.5 - 17 Sep 2014
---
Various of bug fixes
Improved error handling
Added logging for queuing of processes, tasks and jobs

v0.0.4 - 12 Sep 2014
---
Improvements to serialization; make use of GlobalID functionality
Added support for "job" tasks; reusing existing workers as tasks

v0.0.3 - 2 Sep 2014
---
Added failure steps to workflow of processes and tasks

v0.0.2 - 12 Aug 2014
---
Refactored how tasks are defined in definitions

v0.0.1 - 12 Aug 2014
---
Initial release