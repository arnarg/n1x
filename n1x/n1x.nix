{
  runCommand,
  lib,
  bash,
  coreutils,
  findutils,
  jq,
}:
runCommand "n1x" {
  preferLocalBuild = true;
} ''
  install -v -D -m755  ${./n1x} $out/bin/n1x

  substituteInPlace $out/bin/n1x \
    --subst-var-by bash "${bash}" \
    --subst-var-by DEP_PATH "${
    lib.makeBinPath [
      coreutils
      findutils
      jq
    ]
  }"
''
