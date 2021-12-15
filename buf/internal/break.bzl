"""Defines buf_breaking_test rule"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load(":common.bzl", "protoc_plugin_test")

_DOC = """
This checks protocol buffers for breaking changes using `buf breaking`. For an overview of breaking change detection using buf please refer: https://docs.buf.build/breaking/overview.

**NOTE**: In order to truly check breaking changes this rule should be used to check all `proto_library` targets that come under a [buf module](https://docs.buf.build/bsr/overview#module). Using unique test targets for each `proto_library` target checks each `proto_library` target in isolation. Checking targets/packages in isolation has the obvious caveat of not being able to detect when an entire package/target is removed/moved.

**Example**

This rule depends on `proto_library` rule.

```starlark
load("@rules_buf//buf:defs.bzl", "buf_breaking_test")
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

buf_breaking_test(
    name = "foo_proto_breaking",
    # Image file to check against
    against = "@build_buf_foo_foo//:file",
    targets = [":foo_proto"],
    use_rules = ["DEFAULT"],
)
```
"""

_TOOLCHAIN = str(Label("//tools/protoc-gen-buf-breaking:toolchain_type"))

def _buf_breaking_test_impl(ctx):
    proto_infos = [t[ProtoInfo] for t in ctx.attr.targets]
    config = json.encode({
        "against_input": ctx.file.against.path,
        "limit_to_input_files": ctx.attr.limit_to_input_files,
        "exclude_imports": ctx.attr.exclude_imports,
        "input_config": {
            "version": "v1",
            "breaking": {
                "use": ctx.attr.use_rules,
                "except": ctx.attr.except_rules,
                "ignore_unstable_packages": ctx.attr.ignore_unstable_packages,
            },
        },
    })

    return protoc_plugin_test(ctx, proto_infos, ctx.executable._protoc, ctx.toolchains[_TOOLCHAIN].cli, config, [ctx.file.against])

buf_breaking_test = rule(
    implementation = _buf_breaking_test_impl,
    doc = _DOC,
    attrs = {
        "_protoc": attr.label(
            default = "@com_google_protobuf//:protoc",
            executable = True,
            cfg = "exec",
        ),
        "targets": attr.label_list(
            providers = [ProtoInfo],
            doc = """`proto_library` targets to check for breaking changes""",
        ),
        "against": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The image file against which breaking changes are checked. This is typically derived from HEAD/last release tag of your repo/bsr. `rules_buf` provides a repository rule(`buf_image`) to reference an image from the buf schema registry",
        ),
        # buf config attrs
        "use_rules": attr.string_list(
            default = ["FILE"],
            doc = "https://docs.buf.build/breaking/configuration#use",
        ),
        "except_rules": attr.string_list(
            default = [],
            doc = "https://docs.buf.build/breaking/configuration#except",
        ),
        "limit_to_input_files": attr.bool(
            default = True,
            doc = "https://docs.buf.build/breaking/protoc-plugin",
        ),
        "ignore_unstable_packages": attr.bool(
            default = False,
            doc = "https://docs.buf.build/breaking/configuration#ignore_unstable_packages",
        ),
        "exclude_imports": attr.bool(
            default = True,
            doc = "https://docs.buf.build/breaking/protoc-plugin",
        ),
        "ignore": attr.string_list(
            default = [],
            doc = "https://docs.buf.build/breaking/configuration#ignore",
        ),
        "ignore_only": attr.string_list_dict(
            doc = "https://docs.buf.build/breaking/configuration#ignore_only",
        ),
    },
    toolchains = [_TOOLCHAIN],
    test = True,
)