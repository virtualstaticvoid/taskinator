# How to contribute

All kinds of contributions are welcome. By participating you agree to follow the [code of conduct].

If you find an issue, have an idea for a new feature or any improvement, you can report them 
as issues or submit pull requests. To maintain an organized process, please read the following 
guidelines before submitting.

## Reporting Issues

Before reporting new issues, please verify if there are any existing issues for the same problem 
by searching in [issues].

Please make sure to give a clear name to the issue and describe it with all relevant information. 
Giving examples can help understand your suggestion or, in case of issues to reproduce the problem.

## Sending Pull Requests

Look at existing [issues] to see if there are any related issues that your feature/fix should 
consider. If there are none, please create one describing your implementations intent. You should 
always mention a related issue in the pull request description.

While writing code, follow the code conventions that you find in the existing code.

Try to write short, clear and objective commit messages too. You can squash your commits and
improve your commit messages once your done.

Also make sure to add good tests to your new code. Only refactoring of tested features and 
documentation do not need new tests. This way your changes will be documented and future 
changes will not break what you added.

### Step-by-step

- Fork the repository.
- Commit and push until your are happy of what you have done.
- Execute the full test suite to ensure all is passing.
- Squash commits if necessary.
- Push to your repository.
- Open a pull request to the original repository.
- Give your pull request a good description. Do not forget to mention a related issue.

## Running Tests

Once you cloned the gem to your development environment, you should run the following command 
from the root folder to install the project dependencies.

```bash
./bin/setup
```

After that, you can execute the tests suite by running the following command from the root folder.

```bash
rake spec
```

[code of conduct]: CODE_OF_CONDUCT.md
[issues]: https://github.com/virtualstaticvoid/taskinator/issues
