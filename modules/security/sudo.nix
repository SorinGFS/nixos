# Require the host's alternative administrative access instead of sudo.
{ ... }:
{
    security.sudo.enable = false;
}
