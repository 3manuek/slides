<xsl:stylesheet
    xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    version='1.0'>

    <xsl:import href='/usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl'/>

    <!-- General -->
    <xsl:param name="paper.type" select="'A4'"></xsl:param>
    <xsl:param name="section.autolabel" select="0"></xsl:param>
    <xsl:param name="part.autolabel" select="0"></xsl:param>
    <xsl:param name="chapter.autolabel" select="0"></xsl:param>
    <xsl:param name="basefontsize" select="'10pt'"></xsl:param>
    <xsl:param name="body.start.indent" select="'5pt'"></xsl:param>
    <xsl:param name="ulink.show" select="0"/>
    <xsl:param name="insert.xref.page.number">no</xsl:param>
    <xsl:param name="body.font.family">Helvetica</xsl:param>
    <xsl:param name="body.font.master">10</xsl:param>
    <xsl:param name="body.font.size">10pt</xsl:param>
    <xsl:param name="body.margin.top">1in</xsl:param>
    <xsl:param name="body.margin.bottom">1in</xsl:param>
    <xsl:param name="header.rule" select="0"></xsl:param>
    <xsl:param name="footer.rule" select="0"></xsl:param>

    <!-- Lists -->
    <xsl:attribute-set name="list.item.spacing">
        <xsl:attribute name="space-before.optimum">0.0em</xsl:attribute>
        <xsl:attribute name="space-before.minimum">0.0em</xsl:attribute>
        <xsl:attribute name="space-before.maximum">0.0em</xsl:attribute>
    </xsl:attribute-set>

    <!-- Titles -->
    <xsl:param name="title.font.family">Helvetica</xsl:param>
    <xsl:attribute-set name="section.title.properties">
        <xsl:attribute name="font-family">
           <xsl:value-of select="$title.font.family"/>
        </xsl:attribute>
        <xsl:attribute name="font-weight">bold</xsl:attribute>
        <!-- font size is added dynamically by section.heading template -->
        <xsl:attribute name="keep-with-next.within-column">always</xsl:attribute>
        <xsl:attribute name="space-before.minimum">2em</xsl:attribute>
        <xsl:attribute name="space-before.optimum">2em</xsl:attribute>
        <xsl:attribute name="space-before.maximum">2em</xsl:attribute>
        <xsl:attribute name="space-after.minimum">0.0em</xsl:attribute>
        <xsl:attribute name="space-after.optimum">0.0em</xsl:attribute>
        <xsl:attribute name="space-after.maximum">0.0em</xsl:attribute>
        <xsl:attribute name="text-align">left</xsl:attribute>
        <xsl:attribute name="start-indent">0pt</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="section.title.level1.properties">
        <xsl:attribute name="color">#173d68</xsl:attribute>
        <xsl:attribute name="font-size">
            <xsl:value-of select="$body.font.master * 1.6" />
            <xsl:text>pt</xsl:text>
        </xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="section.title.level2.properties">
        <xsl:attribute name="font-size">
            <xsl:value-of select="$body.font.master * 1.3" />
            <xsl:text>pt</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="space-before.minimum">0em</xsl:attribute>
        <xsl:attribute name="space-before.optimum">0em</xsl:attribute>
        <xsl:attribute name="space-before.maximum">0em</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="section.title.level3.properties">
        <xsl:attribute name="font-size">
            <xsl:value-of select="$body.font.master * 1.1" />
            <xsl:text>pt</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="space-before.minimum">0em</xsl:attribute>
        <xsl:attribute name="space-before.optimum">0em</xsl:attribute>
        <xsl:attribute name="space-before.maximum">0em</xsl:attribute>
    </xsl:attribute-set>

    <!-- Pagebreak -->
    <xsl:template match="processing-instruction('asciidoc-pagebreak')">
	<fo:block break-after='page'/>
    </xsl:template>

    <!-- TOC: disable -->
    <xsl:param name="generate.toc">
        appendix  nop
        article   nop,title
        book      nop,title,figure,table,example,equation
        chapter   nop
        part      nop
        preface   nop
        qandadiv  nop
        qandaset  nop
        reference nop,title
        sect1     nop
        sect2     nop
        sect3     nop
        sect4     nop
        sect5     nop
        section   nop
        set       nop
    </xsl:param>

    <!-- Programlisting -->
    <xsl:attribute-set name="monospace.verbatim.properties">
        <xsl:attribute name="font-family">Courier</xsl:attribute>
        <xsl:attribute name="font-size">8pt</xsl:attribute>
    </xsl:attribute-set>
    <xsl:param name="shade.verbatim" select="1" />
    <xsl:attribute-set name="shade.verbatim.style">
        <xsl:attribute name="background-color">#EEEEEE</xsl:attribute>
        <xsl:attribute name="padding">2pt</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="monospace.verbatim.properties">
        <xsl:attribute name="wrap-option">wrap</xsl:attribute>
    </xsl:attribute-set>

    <!-- Tables -->
    <xsl:attribute-set name="table.properties" use-attribute-sets="formal.object.properties">
        <xsl:attribute name="keep-together.within-column">always</xsl:attribute>
        <xsl:attribute name="hyphenate">true</xsl:attribute>
    </xsl:attribute-set>
    <xsl:param name="table.frame.border.thickness">1px</xsl:param>
    <xsl:param name="table.frame.border.color">#153d68</xsl:param>
    <xsl:param name="table.cell.border.style">solid</xsl:param>
    <xsl:param name="table.cell.border.thickness">0px</xsl:param>
    <xsl:param name="table.cell.border.color">#999999</xsl:param>
    <xsl:template name="revhistory" />
    <xsl:template name="table.row.properties">
        <xsl:variable name="rownum">
            <xsl:number from="tgroup" count="row"/>
        </xsl:variable>
        <xsl:if test="ancestor::thead">
            <xsl:attribute name="background-color">#153d68</xsl:attribute>
            <xsl:attribute name="color">#FFFFFF</xsl:attribute>
        </xsl:if>
        <xsl:if test="$rownum mod 2 = 0">
            <xsl:attribute name="background-color">#DDDDDD</xsl:attribute>
        </xsl:if>
    </xsl:template>
    <xsl:template name="table.layout">
        <xsl:param name="table.content" />
        <fo:table width="100%">
            <fo:table-body start-indent="0pt">
                <fo:table-row>
                    <fo:table-cell>

                        <fo:table>
                            <fo:table-body start-indent="0pt">
                                <fo:table-row>
                                    <fo:table-cell>
                                        <fo:block   text-align="left"
                                                    wrap-option="wrap"
                                                    hyphenation-keep="auto"
                                                    font-size="80%">
                                            <xsl:copy-of select="$table.content"/>
                                        </fo:block>
                                    </fo:table-cell>
                                </fo:table-row>
                            </fo:table-body>
                        </fo:table>

                    </fo:table-cell>
                </fo:table-row>
            </fo:table-body>
        </fo:table>
    </xsl:template>
    <xsl:attribute-set name="informaltable.properties"
        xsl:use-attribute-sets="table.properties" />

    <!-- URL: http://code.google.com/p/asciidoc/source/browse/docbook-xsl/fo.xsl?spec=svn1d6a26565e0eb1fb4fccac7d56d33803968e7745&r=1d6a26565e0eb1fb4fccac7d56d33803968e7745 -->
	<xsl:template match="processing-instruction('asciidoc-br')">
		<fo:block/>
	</xsl:template>

	<!-- itemlists -->
	<xsl:template match="variablelist">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="varlistentry">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="varlistentry/term">
		<fo:block
				font-weight="bold"
				space-after="0mm"
				space-before="5pt"
				keep-with-next.within-page="2"
				color="#173d68"
		>
			<xsl:apply-templates/>
		</fo:block>
	</xsl:template>
	<xsl:template match="varlistentry/listitem">
		<fo:block
			margin-left="10mm"
			space-after="10pt"
		>
			<xsl:apply-templates/>
		</fo:block>
	</xsl:template>



    <xsl:template match="title" mode="article.titlepage.recto.auto.mode">
        <fo:block xmlns:fo="http://www.w3.org/1999/XSL/Format"
            text-align="left"
            margin-bottom="50pt"
            >
            <fo:external-graphic
                src="common/2ndquadrant-logo-big.png"
                width="50%"
                content-width="scale-to-fit"
            />
        </fo:block>
        <fo:block xmlns:fo="http://www.w3.org/1999/XSL/Format"
            xsl:use-attribute-sets="chapter.titlepage.recto.style"
            margin-top="0pt"
            space-before="0pt"
            padding-top="5px"
            padding-bottom="15px"
            margin-bottom="0pt"
			space-after="0pt"
            background-color="#EEEEEE"
            margin-left="{$title.margin.left}"
            font-size="24.8832pt"
            font-weight="bold"
            font-family="{$title.font.family}">
            <xsl:call-template name="component.title">
                <xsl:with-param name="node" select="ancestor-or-self::article[1]"/>
            </xsl:call-template>
        </fo:block>
    </xsl:template>

    <xsl:template match="author" mode="titlepage.mode">
        <fo:block color="#173d68"
			space-before="0pt"
            padding-top="0pt"
            margin-top="0pt"
            margin-bottom="50pt"
            padding-right="5pt"
            text-align="left"
            font-size="80%"
            >
            <xsl:call-template name="anchor"/>
            <xsl:choose>
                <xsl:when test="orgname">
                    <xsl:apply-templates/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="person.name"/>
                    <xsl:if test="affiliation/orgname">
                        <xsl:text>, </xsl:text>
                        <xsl:apply-templates select="affiliation/orgname" mode="titlepage.mode"/>
                    </xsl:if>
                    <xsl:if test="email|affiliation/address/email">
                        <xsl:text> </xsl:text>
                        <xsl:apply-templates select="(email|affiliation/address/email)[1]"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </fo:block>
    </xsl:template>

    <!-- Footer -->
    <xsl:param name="footer.column.widths">0.50 0.10 0.40</xsl:param>
    <xsl:template name="footer.content">
        <xsl:param name="pageclass" select="''"/>
        <xsl:param name="sequence" select="''"/>
        <xsl:param name="position" select="''"/>
        <xsl:param name="gentext-key" select="''"/>
        <xsl:choose>
            <xsl:when test="$sequence != 'first' and $position = 'left'">
                Copyright &#169; <xsl:value-of select="$copyrightyear" />,
                <xsl:value-of select="$copyrightholder" />
            </xsl:when>
            <xsl:when test="$sequence != 'first' and $position = 'center'">
                <fo:page-number />
            </xsl:when>
            <xsl:when test="$sequence != 'first' and $position = 'right'">
            <fo:external-graphic content-height="0.5cm">
                <xsl:attribute name="src">
                <xsl:call-template name="fo-external-image">
                    <xsl:with-param name="filename" select="$footer.image.filename" />
                </xsl:call-template>
            </xsl:attribute>
            </fo:external-graphic>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
