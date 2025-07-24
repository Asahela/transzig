# Transzig  
A CLI toy for a minimal implementation of a regular expression processor.
> [!Note]
> The current version can only generate regular language over ascii characters and symbols.
# Table of Contents  
  * [Installation](#installation)
  * [Usage](#usage)
  * [Task list](#task-list)
  * [Contributing](#contributing)
## Installation
1) Download and intall Zig from the official [Zig Programming Language](https://ziglang.org/) page.
2) Clone this repository and build the project :
```bash
git clone https://github.com/Asahela/transzig.git
cd transzig
zig build
```
## Usage
`transzig [<regexp>] [<string>]`
The command will output a boolean value based on whether the regexp generates or not the string. 
## Task list
- [X] Epsilon transition
- [X] Character
- [ ] Group
- [X] Repetition
- [X] Alternation
- [X] Disjunction
- [ ] Negation
- [ ] Character class
- [ ] NFA to DFA converter
- [ ] DFA minimization
## Contributing
Feel free to explore the source code and contribute to the project.
