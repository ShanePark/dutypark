type PublicContentLabelValue = string | number

export function formatPublicContentLabel(
  template: string,
  values: Record<string, PublicContentLabelValue>,
): string {
  return template.replace(/\{([^{}]+)\}/g, (placeholder, key: string) =>
    Object.prototype.hasOwnProperty.call(values, key) ? String(values[key]) : placeholder,
  )
}
