# Sloth Runner Package

This directory contains the Nix package definition for Sloth Runner.

## Structure

- `sloth-runner.nix` - Main package definition using `buildGoModule`
- `default.nix` - Package exports for easy importing

## Updating the Package

### Update to Latest Commit

1. Get the latest commit hash from the main sloth-runner repository:
   ```bash
   git ls-remote https://github.com/chalkan3/sloth-runner.git HEAD
   ```

2. Calculate the new hash in SRI format:
   ```bash
   # Download and get the base32 hash
   HASH_BASE32=$(nix-prefetch-url --unpack "https://github.com/chalkan3/sloth-runner/archive/NEW_COMMIT_HASH.tar.gz")

   # Convert to SRI format (base64)
   nix-hash --type sha256 --to-base64 $HASH_BASE32
   ```

3. Update the file with SRI format hash:
   ```nix
   rev = "NEW_COMMIT_HASH";
   hash = "sha256-BASE64_HASH_HERE";  # Note: "hash" not "sha256"
   ```

**Important**: Modern Nix uses SRI (Subresource Integrity) format:
- Use `hash = "sha256-...";` (base64 encoding)
- NOT `sha256 = "...";` (old base32 format)

### Update vendorHash (if Go dependencies change)

If the Go dependencies (go.mod/go.sum) change, you may need to update `vendorHash`:

1. Set `vendorHash = lib.fakeHash;` temporarily
2. Try to build:
   ```bash
   nix build .#sloth-runner
   ```
3. The error message will show the correct hash:
   ```
   error: hash mismatch in fixed-output derivation
      specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
         got:    sha256-REAL_HASH_HERE
   ```
4. Update `vendorHash` with the real hash from the error message

**Note**: Currently `vendorHash = null` works because the project uses Go modules without vendoring.

## Testing the Package

Build the package:
```bash
nix build .#sloth-runner
```

Run the binary:
```bash
./result/bin/sloth-runner --version
```

Check what's in the package:
```bash
nix path-info --recursive .#sloth-runner
```

## Cross-Compilation

Build for different architectures:

```bash
# Build for ARM64
nix build .#sloth-runner --system aarch64-linux

# Build for x86_64
nix build .#sloth-runner --system x86_64-linux
```

## Integration with Binary Cache

The package is designed to work with binary caches (Cachix, Hydra):

1. Build the package in CI
2. Push to cache: `cachix push my-cache ./result`
3. Users pull from cache automatically

See `ARCHITECTURE.md` for more details.

## Version Pinning

The package uses a specific commit hash instead of a branch name to ensure reproducibility. When updating, always use a commit hash, not "master" or "main".

### Using Tagged Releases

When sloth-runner has tagged releases, update like this:

```nix
src = fetchFromGitHub {
  owner = "chalkan3";
  repo = "sloth-runner";
  rev = "v0.1.0";  # Use tag
  hash = "sha256-...";  # SRI format - calculate with nix-prefetch-url + nix-hash
};
```

## Troubleshooting

### Build Fails with "hash mismatch"

The `hash` is incorrect or in wrong format. Recalculate using:
```bash
HASH_BASE32=$(nix-prefetch-url --unpack "https://github.com/chalkan3/sloth-runner/archive/COMMIT_HASH.tar.gz")
nix-hash --type sha256 --to-base64 $HASH_BASE32
```
Then use: `hash = "sha256-BASE64_RESULT";`

### Build Fails with "vendorHash mismatch"

The Go dependencies have changed. Follow the "Update vendorHash" section above.

### CGO Errors

The package requires CGO for SQLite support. Ensure `sqlite` and `pkg-config` are in `buildInputs` and `nativeBuildInputs`.

### Missing Dependencies

If build fails with missing dependencies, they should be added to:
- `buildInputs` - Runtime dependencies
- `nativeBuildInputs` - Build-time tools

## Contributing

When submitting updates to this package:

1. Test the build locally
2. Verify the binary works
3. Update the version number if applicable
4. Document any dependency changes
5. Test on both x86_64 and aarch64 if possible
