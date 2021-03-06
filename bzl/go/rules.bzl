load("//bzl:protoc.bzl", "protoc_genrule", "implement")
load("//bzl:go/class.bzl", GO = "CLASS")
load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_proto_compile = implement(["go"])

def go_proto_library(
    name,
    protos,
    lang = GO,
    srcs = [],
    imports = [],
    visibility = None,
    testonly = 0,
    protoc = None,
    protobuf_plugin = None,
    with_grpc = False,
    verbose = 0,
    **kwargs):

  result = protoc_genrule(
    spec = [lang],
    name = name + "_pb",
    protos = protos,
    protoc = protoc,
    protobuf_plugin = protobuf_plugin,
    visibility = visibility,
    testonly = testonly,
    imports = imports,
    with_grpc = with_grpc,
    verbose = verbose,
  )

  if with_grpc:
    deps = [str(Label(dep)) for dep in getattr(lang.grpc, "compile_deps", [])]
  else:
    deps = [str(Label(dep)) for dep in getattr(lang.protobuf, "compile_deps", [])]

  go_library(
    name = name,
    srcs = result.outs,
    deps = deps,
    **kwargs
  )
