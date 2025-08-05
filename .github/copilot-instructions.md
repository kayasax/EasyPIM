# 🧠 Advanced GitHub Copilot Instructions for Maximum Productivity

## 🎯 Core Session Management & Context Awareness

**ALWAYS when starting any session:**
1. 📘 **Context Priority**: Look for `Session_starter.md` first, then `README.md`, then project files for context
2. 🔄 **Live Documentation**: Update `Session_starter.md` with progress, decisions, discoveries, and architectural insights
3. 🎯 **Pattern Recognition**: Follow established patterns, coding standards, and technical decisions from session files
4. 📅 **Progress Tracking**: Add significant changes to update log using format: `| Date | Summary |`
5. ✅ **Task Management**: Mark completed next steps as `[x] ✅ COMPLETED` and add new actionable items
6. 🔍 **Decision Context**: Reference session context when making technical decisions and explain reasoning
7. 🔧 **Tool Utilization**: Check for and utilize available MCP servers, VS Code extensions, and workspace tools
8. 🎨 **Code Quality**: Apply industry best practices, design patterns, and maintain consistent code style

## 📁 Intelligent File & Context Management

**Session File Priority & Discovery:**
- **Primary**: `Session_starter.md` - project memory and context
- **Secondary**: `README.md` - project overview and setup
- **Tertiary**: Scan workspace root, parent directory, `.vscode/`, `docs/`, and common subdirectories
- **Auto-Discovery**: Detect project type (React, Node.js, Python, .NET, etc.) and adjust behavior accordingly
- **Missing Files**: Offer to create session continuity files when missing

**Context Enhancement:**
- **Reference Strategy**: Use `#file:`, `#selection:`, and workspace symbols for precise context
- **Scope Management**: Understand current file, selection, and workspace scope in responses
- **Symbol Recognition**: Leverage IntelliSense and workspace indexing for accurate suggestions

## 🔧 Advanced Tool Integration & Capabilities

**MCP Server Integration:**
- **Check available MCP servers** at session start with a brief mention
- **Use Microsoft documentation MCP** for accurate Azure/Microsoft product information
- **Leverage other available MCP servers** when they provide relevant capabilities
- **Mention MCP server usage** when you use tools from external servers
- **Example**: "Using Microsoft docs MCP to get latest Azure information..."

**VS Code Extension Leverage:**
- **Detect Extensions**: Identify and utilize available VS Code extensions (ESLint, Prettier, GitLens, etc.)
- **Tool Integration**: Suggest extension-specific workflows and configurations
- **Terminal Usage**: Prefer integrated terminal with appropriate shell commands for user's OS
- **Debugging**: Utilize VS Code debugging capabilities and suggest breakpoint strategies

**Workspace Intelligence:**
- **Project Type Detection**: Automatically recognize technology stack and adjust suggestions
- **Dependency Management**: Understand package.json, requirements.txt, .csproj patterns
- **Build Systems**: Recognize and work with npm scripts, Maven, Gradle, Make, etc.
- **Testing Frameworks**: Identify and suggest appropriate testing patterns for the project

## 🎯 Enhanced Communication & Response Patterns

**Granular Response Strategy:**
- **Break Down Complex Tasks**: Split large requests into smaller, manageable steps
- **Step-by-Step Explanations**: Provide clear progression for complex implementations
- **Context Validation**: Confirm understanding before proceeding with major changes
- **Alternative Solutions**: Offer multiple approaches with trade-offs when applicable

**Code Generation Excellence:**
- **Follow Project Conventions**: Match existing code style, naming patterns, and architecture
- **Security First**: Never include secrets, API keys, or sensitive data in code suggestions
- **Error Handling**: Include comprehensive error handling and validation in generated code
- **Documentation**: Add meaningful comments and JSDoc/docstrings for functions and classes
- **Testing Considerations**: Suggest testable code patterns and potential test cases

**Professional Communication:**
- **Clear Explanations**: Use technical accuracy while maintaining accessibility
- **Visual Organization**: Use markdown formatting, lists, and code blocks effectively
- **Reference Documentation**: Link to relevant docs when suggesting libraries or patterns
- **Version Awareness**: Consider compatibility and version requirements for dependencies

## 📊 Session Memory & Learning Discipline

**Update Discipline:**
- Add meaningful progress to the update log section
- Update "Assistant Memory" section with new discoveries and learnings
- Maintain professional, concise update format
- Track technical constraints, architecture decisions, and solved problems
- Note any MCP server tools used during the session

**Productivity Focus:**
- Leverage session memory to avoid re-explaining established context
- Build upon previous session achievements and patterns
- Maintain consistency in coding style and architectural approaches
- Provide seamless continuity across development sessions
- Utilize available MCP servers to enhance capabilities and accuracy

## 🚀 Advanced Prompt Engineering Techniques

**Prompt Optimization:**
- **Be Specific**: Use clear, unambiguous language with concrete examples
- **Set Expectations**: Define desired output format, style, and constraints upfront
- **Add Context**: Include relevant technical background, project constraints, and requirements
- **Break Down Requests**: Split complex tasks into smaller, focused prompts for better results
- **Use Examples**: Provide sample inputs/outputs when requesting specific formats

**Agent Mode Best Practices:**
- **Allow Tool Usage**: Let Copilot use available tools and extensions rather than manual intervention
- **Granular Prompts**: Keep individual requests focused on single responsibilities
- **Express Preferences**: Clearly state preferred approaches, frameworks, or patterns
- **Enable Repetition**: Allow Copilot to repeat tasks for better context understanding
- **Provide Feedback**: Use thumbs up/down and detailed feedback to improve responses

## 🔍 Workspace-Aware Intelligence

**Smart File Discovery:**
- **Auto-detect** configuration files (package.json, tsconfig.json, .eslintrc, etc.)
- **Recognize** project patterns and suggest appropriate tooling
- **Identify** testing frameworks and build systems in use
- **Leverage** existing code patterns and architectural decisions
- **Suggest** improvements based on industry best practices

**Context-Aware Responses:**
- **Reference** specific files, functions, and variables from the current workspace
- **Understand** the current selection, cursor position, and active file
- **Maintain** consistency with existing code style and naming conventions
- **Consider** project dependencies and version constraints
- **Adapt** suggestions to the detected technology stack

## Project Context Awareness

When working on development projects:
- Follow established technology stack patterns from session memory
- Reference previous debugging solutions and architectural decisions
- Maintain consistency with team coding standards documented in session files
- Build incrementally on documented progress and achievements
- Use MCP servers for accurate, up-to-date information when needed

**This ensures consistent, productive development sessions with persistent project memory and enhanced AI capabilities through MCP server integration.**