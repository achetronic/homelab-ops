<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output omit-xml-declaration="yes" indent="yes"/>

    <xsl:template match="node()|@*">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*"/>
        </xsl:copy>
    </xsl:template>

    <!-- Fix: Connect a cdrom device on SATA instead of IDE bus -->
    <xsl:template match="/domain/devices/disk[@device='cdrom']/target/@bus">
        <xsl:attribute name="bus">
            <xsl:value-of select="'sata'"/>
        </xsl:attribute>
    </xsl:template>

    ${~

    # 1. Delete comments
    # 2. Trim unneeded spaces or new lines
    # 3. Delete potentially conflicting XSLT tags

    replace(replace(replace(user_xslt,
        "/<!--[\\s\\S]*?-->/", ""),
        "/\\s+\\n/", ""),
        "/<(\\?)?(/)?(?:xml|xsl:stylesheet|xsl:transform)[^>]*>/", "")
    ~}
</xsl:stylesheet>
