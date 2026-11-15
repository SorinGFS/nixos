# Require local root authentication instead of sudo for administration.
{ ... }:
{
    security.sudo.enable = false;
}
