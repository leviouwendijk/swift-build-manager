
---

# Swift Build Manager (`sbm`)

Swift Build Manager (`sbm`) is a streamlined tool for building and deploying Swift binaries. It manages its own `sbm-bin` directory for binaries in your home root, providing a separated space for your custom build binaries. It auto-overwrites them when rebuilding, and will create the dir + add it to your .zshrc if not already done so.

## Features

- **Automated Build and Deployment**: Builds Swift projects and deploys binaries to a specified directory with a single command.
- **Automatic Overwrite**: Handles existing binaries in the destination directory and overwrites them as needed.

## Installation

Ensure: **Swift** is installed.

`sbm` will check automatically if its binary folder is in your path, and will otherwise try to add it:

```bash
export PATH="$HOME/sbm-bin:$PATH"
```

## Usage

### Basic Command

```bash
sbm -r
```

- **-r**: Runs the build in release mode.

### Workflow

1. **Build Process**:
   - **Build Command**: Automatically runs either `swift build -c debug` or `swift build -c release` depending on the build type specified.
   - **Target Detection**: Attempts to identify the binary target from the specified directory.
   - **Error Handling**: Outputs any issues if the build fails or the target cannot be determined.

2. **Deployment Process**:
   - **Destination Directory**: Copies or replaces the binary in the specified `destinationPath`.
   - **File Handling**:
     - If the binary already exists at `destinationPath`, it is replaced with the new build.
     - If the binary doesn’t exist, it is created as usual.
   - **Output Messages**: Logs warnings when overwriting an existing file and errors for any deployment issues.

## Edge Cases & Notes

1. **Binary Exists**: If a binary already exists in `sbm-bin`, it will be replaced automatically. A warning is printed for each replacement.
2. **Failed Build**: If the build command fails, `sbm` will display an error message and exit without deploying.

---

## Example Workflow

```swift
func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String)
```

### Parameters

- **buildType**: Specifies `.debug` or `.release` build type.
- **targetDirectory**: The root directory of the project to build.
- **destinationPath**: The directory where the built binary is to be copied.

### Example

Default, using currently selected directory and copying binary output to `sbm-bin`:

```bash
sbm -r 
```

Adding a specific project directory:

```bash
sbm -r /myproject/path
```

Adding a specific output directory where the binary will be placed:

```bash
sbm -r /myproject/path /my/bin
```


---



