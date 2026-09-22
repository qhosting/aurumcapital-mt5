"use client"

import * as React from "react"
import { Check } from "lucide-react"
import { cn } from "@/lib/utils"

export interface CheckboxProps
  extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "onChange"> {
  checked?: boolean
  defaultChecked?: boolean
  onCheckedChange?: (checked: boolean) => void
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void
}

const Checkbox = React.forwardRef<HTMLInputElement, CheckboxProps>(
  ({ className, checked, defaultChecked, onCheckedChange, onChange, disabled, ...props }, ref) => {
    const isControlled = checked !== undefined
    const [internalChecked, setInternalChecked] = React.useState<boolean>(
      Boolean(defaultChecked ?? false)
    )

    const isChecked = isControlled ? Boolean(checked) : internalChecked

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      if (disabled) return
      const nextChecked = e.target.checked
      if (!isControlled) {
        setInternalChecked(nextChecked)
      }
      onChange?.(e)
      onCheckedChange?.(nextChecked)
    }

    return (
      <span className="relative inline-flex items-center justify-center align-middle">
        <input
          type="checkbox"
          ref={ref}
          className="peer sr-only"
          checked={isChecked}
          disabled={disabled}
          onChange={handleChange}
          {...props}
        />
        <span
          className={cn(
            "flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border transition-colors cursor-pointer",
            isChecked
              ? "bg-[#D4AF37] border-[#D4AF37] text-[#0A192F]"
              : "border-gray-500 bg-[#0A192F] hover:border-gray-400",
            disabled && "cursor-not-allowed opacity-50",
            className
          )}
          onClick={(e) => {
            if (disabled) return
            e.preventDefault()
            const nextChecked = !isChecked
            if (!isControlled) {
              setInternalChecked(nextChecked)
            }
            onCheckedChange?.(nextChecked)
          }}
        >
          {isChecked && <Check className="h-3.5 w-3.5 stroke-[3] text-[#0A192F]" />}
        </span>
      </span>
    )
  }
)
Checkbox.displayName = "Checkbox"

export { Checkbox }
