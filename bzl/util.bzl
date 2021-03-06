#load("//bzl:classes.bzl", "CLASSES")

# This should be set to the length of the longest CLASSES heirarcy
# chain.  By definition, it cannot be longer than the lienght of the
# list itself.  This is hardcoded to avoid dependency cycle.
#
MAX_INVOKE_DEPTH = range(4)

def invokeall(name, lang, self):
    current = lang
    """Invoke the all methods found on the class chain"""
    for i in MAX_INVOKE_DEPTH:
        if current == None:
            return
        if hasattr(current, name):
            method = getattr(current, name)
            method(lang, self)
        current = getattr(current, "parent", None)


def invokesuper(name, lang, self):
    current = getattr(lang, "parent", None)
    """Invoke the first method found on the superclass chain"""
    for i in MAX_INVOKE_DEPTH:
        if current == None:
            return
        if hasattr(current, name):
            method = getattr(current, name)
            method(lang, self)
            return
        current = getattr(current, "parent", None)


def invoke(name, lang, self):
    current = lang
    """Invoke the first method found on the class chain"""
    for i in MAX_INVOKE_DEPTH:
        if current == None:
            return
        if hasattr(current, name):
            method = getattr(current, name)
            method(lang, self)
            return
        current = getattr(current, "parent", None)


def require(target, context):
    """Load external dependency during WORKSPACE loading.

    Args:
      context: The loading context

    Returns:
      the return value of the native repository rule.

    """
    repos = context.repos
    opts = context.options

    dep = repos.get(target)
    opt = opts.get(target) or {}
    verbose = context.verbose
    #verbose = True

    # Is the dep defined?
    if not dep:
        fail("Undefined dependency: " + target)

    name = dep.get("name")
    kind = dep.get("kind")
    if not name:
        fail("Dependency target %s is missing required attribute 'name': " % target)
    if not kind:
        fail("Dependency target %s is missing required attribute 'kind': " % target)

    #print("dep: %s" % dep.items())

    # Should it be omitted?
    if opt.get("omit"):
        #print("omit %s!" % target)
        return

    # Does it already exist?
    defined = native.existing_rule(dep.get("name"))
    if defined:
        hkeys = ["sha256", "sha1", "tag"]
        # If it has already been defined and our dependency lists a
        # hash, do these match? If a hash mismatch is encountered, has
        # the user specifically granted permission to continue?
        for hkey in hkeys:
            expected = dep.get(hkey)
            actual = defined.get(hkey)
            if expected:
                if expected != actual:
                    if opt.grant_hermetic_leak:
                        return
                    else:
                        fail("During require (%s), namespace (%s) already exists in the "
                             + "workspace but the existing %s=%s did not match "
                             + "the required value: %s.  If you feel this is in error, "
                             + "set opts['%s'].grant_hermetic_leak = True" % (target, dep.name, hkey, actual, expected, target))
                else:
                    if verbose:
                        print("Not reloading %s (@%s): %s matches %s" % (target, name, hkey, actual))
                    return

        # No kheys for this rule
        if verbose:
            print("Skipping reload of target %s (no hash keys %s)" % (target, hkeys))
        return

    # If this dependency declares another one, require that one now.
    # OH_SNAP: recursion is not allowed in skylark.  Removing this
    # feature.
    #
    # requires = dep.get("require")
    # if (requires):
    #     for ext in requires:
    #         require(ext, opts)

    rule = getattr(native, kind)
    if not rule:
        fail("During require (%s), kind '%s' has no matching native rule" % (target, dep.kind))

    # Invoke the native rule with the unpacked arguments, without
    # special entries (those that have no corresponding representation
    # in the native struct)
    args = dict(dep.items())
    args.pop("kind")

    if verbose:
        #print("Load %s %s (@%s) with args %s" % (kind, target, name, args))
        print("Load %s (@%s)" % (target, name))

    return rule(**args)
