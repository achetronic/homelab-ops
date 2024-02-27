<?xml version="1.0" ?>
<!--
    This file is merged with a global XSLT that already defines
    tags such as 'xml', 'xsl:stylesheet', 'xsl:transform', or even 'xsl:output'
    Duplicated tags found here will be deleted to make XSLT merge possible.
    They are included here just to keep the XSLT structure canonical
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <!--
        Output parameters
        Not needed as it's already present on parent XSLT

        <xsl:output omit-xml-declaration="yes" indent="yes"/>
    -->

    <!--
        XSLT 1.0 Identity Transform
        Not needed as it's already present on parent XSLT

        <xsl:template match="node()|@*">
            <xsl:copy>
                <xsl:apply-templates select="node()|@*"/>
            </xsl:copy>
        </xsl:template>
    -->

    <!--
        XSLT 3.0 Identity Transform equivalent
        <xsl:mode on-no-match="shallow-copy" />
    -->

    <!-- Attach Sonoff Zigbee 3.0 USB Dongle Plus E -->
    <xsl:template match="/domain/devices">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
            <hostdev mode='subsystem' type='usb' managed='yes'>
                <source>
                    <vendor id='0x1a86'/>
                    <product id='0x55d4'/>
                </source>
                <address type='usb' bus='0' port='1'/>
            </hostdev>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
